package usach.cl.tareasbackend.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

/**
 * Consultas espaciales PostGIS de las preguntas del enunciado.
 * Salvo el reporte agregado (pregunta 6), TODAS son privadas: se evaluan
 * con el id del usuario autenticado, que sale del token JWT.
 * El cast ::geography hace que las distancias salgan en METROS.
 */
@Repository
public class EstadisticaRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public EstadisticaRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** P1: tareas completadas del usuario, agrupadas por sector. */
    public List<Map<String, Object>> tareasPorSector(int idUsuario) {
        String sql = """
                SELECT s.nombre AS sector, COUNT(t.id_tarea) AS tareas_completadas
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                WHERE t.id_usuario = :idUsuario AND t.completada = TRUE
                GROUP BY s.nombre
                ORDER BY tareas_completadas DESC, s.nombre
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("idUsuario", idUsuario));
    }

    /**
     * P2: tarea pendiente mas cercana al usuario (operador KNN <->).
     * El desempate por fecha_vencimiento e id_tarea hace la respuesta
     * DETERMINISTA cuando varias pendientes comparten la misma zona
     * (misma zona = misma distancia).
     */
    public List<Map<String, Object>> tareaMasCercana(int idUsuario) {
        String sql = """
                SELECT t.id_tarea, t.titulo, s.nombre AS sector, t.fecha_vencimiento,
                       ROUND(ST_Distance(u.ubicacion::geography,
                                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                JOIN usuario u ON u.id_usuario = :idUsuario
                WHERE t.id_usuario = :idUsuario AND t.completada = FALSE
                ORDER BY u.ubicacion <-> s.ubicacion, t.fecha_vencimiento, t.id_tarea
                LIMIT 1
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("idUsuario", idUsuario));
    }

    /**
     * P3 y P7: sector con mas tareas completadas DEL USUARIO dentro de un
     * radio en metros (2 km y 5 km). A igual cantidad gana la zona mas
     * cercana: sin ese desempate el resultado seria arbitrario.
     */
    public List<Map<String, Object>> sectorConMasCompletadas(int idUsuario, double radioMetros) {
        String sql = """
                SELECT s.nombre AS sector, COUNT(t.id_tarea) AS tareas_completadas,
                       ROUND(ST_Distance(u.ubicacion::geography,
                                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                JOIN usuario u ON u.id_usuario = :idUsuario
                WHERE t.completada = TRUE
                  AND t.id_usuario = :idUsuario
                  AND ST_DWithin(u.ubicacion::geography, s.ubicacion::geography, :radio)
                GROUP BY s.nombre, u.ubicacion, s.ubicacion
                ORDER BY tareas_completadas DESC,
                         ST_Distance(u.ubicacion::geography, s.ubicacion::geography) ASC
                LIMIT 1
                """;
        var params = new MapSqlParameterSource()
                .addValue("idUsuario", idUsuario)
                .addValue("radio", radioMetros);
        return jdbc.queryForList(sql, params);
    }

    /** P4 y P8: promedio de distancia de las tareas completadas del usuario. */
    public List<Map<String, Object>> promedioDistancia(int idUsuario) {
        String sql = """
                SELECT ROUND(AVG(ST_Distance(u.ubicacion::geography,
                                             s.ubicacion::geography))::numeric, 1)
                       AS promedio_distancia_metros
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                JOIN usuario u ON u.id_usuario = :idUsuario
                WHERE t.id_usuario = :idUsuario AND t.completada = TRUE
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("idUsuario", idUsuario));
    }

    /**
     * P5: agrupacion espacial (K-Means) de las ZONAS con tareas pendientes
     * del usuario. Devuelve, por grupo, el centro, la cantidad de pendientes y
     * radio_metros: la distancia REAL del centro a la zona mas lejana del grupo,
     * es decir su extension geografica. Sin factores de ajuste: el circulo del
     * mapa pasa exactamente por la zona mas lejana. Un grupo de una sola zona
     * tiene extension 0; el minimo visible lo aplica el frontend, porque es una
     * decision de dibujo y no del dato.
     *
     * Dos decisiones importantes:
     *  1) k se ajusta con LEAST(:k, nro de zonas). ST_ClusterKMeans LANZA UN
     *     ERROR si k > filas del grupo, asi que un usuario con una sola zona
     *     pendiente (por ejemplo, uno recien registrado) romperia el endpoint.
     *  2) se clusteriza una fila POR ZONA y no una por tarea: puntos repetidos
     *     hacen que PostGIS avise "duplicate inputs" y devuelva menos grupos
     *     de los pedidos.
     */
    public List<Map<String, Object>> clustersPendientes(int idUsuario, int k) {
        String sql = """
                WITH zonas AS (
                    SELECT s.id_sector, s.nombre, s.ubicacion, COUNT(*) AS pendientes
                    FROM tarea t
                    JOIN sector s ON s.id_sector = t.id_sector
                    WHERE t.completada = FALSE AND t.id_usuario = :idUsuario
                    GROUP BY s.id_sector, s.nombre, s.ubicacion
                ), agrupadas AS (
                    SELECT z.*,
                           ST_ClusterKMeans(z.ubicacion,
                                (SELECT LEAST(:k, COUNT(*))::int FROM zonas)) OVER () AS cluster_id
                    FROM zonas z
                ), grupos AS (
                    SELECT a.cluster_id,
                           SUM(a.pendientes) AS tareas_pendientes,
                           STRING_AGG(a.nombre, ' | ' ORDER BY a.pendientes DESC, a.nombre) AS sectores,
                           ST_Centroid(ST_Collect(a.ubicacion)) AS centro
                    FROM agrupadas a
                    GROUP BY a.cluster_id
                )
                SELECT g.cluster_id, g.tareas_pendientes, g.sectores,
                       ST_Y(g.centro) AS latitud_centro,
                       ST_X(g.centro) AS longitud_centro,
                       ROUND(MAX(ST_Distance(g.centro::geography,
                                             a.ubicacion::geography))::numeric, 0)
                       AS radio_metros
                FROM grupos g
                JOIN agrupadas a ON a.cluster_id = g.cluster_id
                GROUP BY g.cluster_id, g.tareas_pendientes, g.sectores, g.centro
                ORDER BY g.tareas_pendientes DESC, g.cluster_id
                """;
        var params = new MapSqlParameterSource()
                .addValue("idUsuario", idUsuario)
                .addValue("k", Math.max(1, k));
        return jdbc.queryForList(sql, params);
    }

    /**
     * Detalle por zona de la pregunta 5, para el mapa. Devuelve una fila por
     * ZONA con tareas pendientes del usuario, con su cantidad y el grupo
     * (cluster_id) al que la asigno el K-Means. Usa exactamente el mismo CTE y
     * el mismo k que clustersPendientes, asi que los grupos coinciden.
     *
     * Existe porque en el mapa no basta con dibujar el circulo del grupo: hay
     * casos donde el circulo de un grupo encierra zonas que NO son suyas (le
     * pasa al usuario rmorales), asi que la pertenencia hay que mostrarla con
     * color y no con la posicion.
     */
    public List<Map<String, Object>> pendientesPorZona(int idUsuario, int k) {
        String sql = """
                WITH zonas AS (
                    SELECT s.id_sector, s.nombre, s.ubicacion, COUNT(*) AS pendientes
                    FROM tarea t
                    JOIN sector s ON s.id_sector = t.id_sector
                    WHERE t.completada = FALSE AND t.id_usuario = :idUsuario
                    GROUP BY s.id_sector, s.nombre, s.ubicacion
                )
                SELECT z.id_sector, z.nombre,
                       ST_Y(z.ubicacion) AS latitud,
                       ST_X(z.ubicacion) AS longitud,
                       z.pendientes,
                       ST_ClusterKMeans(z.ubicacion,
                            (SELECT LEAST(:k, COUNT(*))::int FROM zonas)) OVER () AS cluster_id
                FROM zonas z
                ORDER BY z.pendientes DESC, z.nombre
                """;
        var params = new MapSqlParameterSource()
                .addValue("idUsuario", idUsuario)
                .addValue("k", Math.max(1, k));
        return jdbc.queryForList(sql, params);
    }

    /**
     * Apoyo visual para P3 y P7: todas las zonas donde el usuario tiene tareas
     * completadas, con su cantidad, su distancia y si caen dentro de los radios
     * de 2 y 5 km. Es la misma informacion que usan P3 y P7, pero sin el LIMIT 1:
     * permite dibujar en el mapa por que gana una zona y no otra.
     */
    public List<Map<String, Object>> completadasPorZona(int idUsuario) {
        String sql = """
                SELECT s.id_sector, s.nombre,
                       ST_Y(s.ubicacion) AS latitud,
                       ST_X(s.ubicacion) AS longitud,
                       COUNT(t.id_tarea) AS tareas_completadas,
                       ROUND(ST_Distance(u.ubicacion::geography,
                                         s.ubicacion::geography)::numeric, 1) AS distancia_metros,
                       ST_DWithin(u.ubicacion::geography, s.ubicacion::geography, 2000) AS dentro_2km,
                       ST_DWithin(u.ubicacion::geography, s.ubicacion::geography, 5000) AS dentro_5km
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                JOIN usuario u ON u.id_usuario = :idUsuario
                WHERE t.id_usuario = :idUsuario AND t.completada = TRUE
                GROUP BY s.id_sector, s.nombre, s.ubicacion, u.ubicacion
                ORDER BY tareas_completadas DESC,
                         ST_Distance(u.ubicacion::geography, s.ubicacion::geography) ASC
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("idUsuario", idUsuario));
    }

    /**
     * P6: reporte agregado "cuantas tareas ha realizado CADA usuario por
     * sector". Es la unica pregunta del enunciado que no esta acotada a la
     * sesion. Expone SOLO conteos: nunca el titulo, la descripcion ni la
     * ubicacion de tareas ajenas.
     */
    public List<Map<String, Object>> tareasPorUsuarioYSector() {
        String sql = """
                SELECT u.nombre_usuario AS usuario, s.nombre AS sector,
                       COUNT(t.id_tarea) AS tareas_completadas
                FROM tarea t
                JOIN usuario u ON u.id_usuario = t.id_usuario
                JOIN sector s  ON s.id_sector  = t.id_sector
                WHERE t.completada = TRUE
                GROUP BY u.nombre_usuario, s.nombre
                ORDER BY u.nombre_usuario, tareas_completadas DESC, s.nombre
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource());
    }
}
