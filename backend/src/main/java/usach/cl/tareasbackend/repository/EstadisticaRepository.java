package usach.cl.tareasbackend.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

/**
 * Consultas espaciales PostGIS de las preguntas del enunciado.
 * TODAS son privadas: se evaluan con el id del usuario autenticado.
 * Las preguntas "por cada usuario" (6 y 8) se responden con la misma
 * consulta de las preguntas 1 y 4, ejecutada por cada sesion.
 * El cast ::geography hace que las distancias salgan en METROS.
 */
@Repository
public class EstadisticaRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public EstadisticaRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Tareas completadas del usuario, agrupadas por sector (preguntas 1 y 6). */
    public List<Map<String, Object>> tareasPorSector(int idUsuario) {
        String sql = """
                SELECT s.nombre AS sector, COUNT(t.id_tarea) AS tareas_completadas
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                WHERE t.id_usuario = :idUsuario AND t.completada = TRUE
                GROUP BY s.nombre
                ORDER BY tareas_completadas DESC
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("idUsuario", idUsuario));
    }

    /** Tarea pendiente mas cercana al usuario (pregunta 2, operador KNN). */
    public List<Map<String, Object>> tareaMasCercana(int idUsuario) {
        String sql = """
                SELECT t.id_tarea, t.titulo, s.nombre AS sector,
                       ROUND(ST_Distance(u.ubicacion::geography,
                                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                JOIN usuario u ON u.id_usuario = :idUsuario
                WHERE t.id_usuario = :idUsuario AND t.completada = FALSE
                ORDER BY u.ubicacion <-> s.ubicacion
                LIMIT 1
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("idUsuario", idUsuario));
    }

    /**
     * Sector con mas tareas completadas DEL USUARIO dentro de un radio en
     * metros (preguntas 3 y 7: radios de 2 y 5 km).
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
                ORDER BY tareas_completadas DESC
                LIMIT 1
                """;
        var params = new MapSqlParameterSource()
                .addValue("idUsuario", idUsuario)
                .addValue("radio", radioMetros);
        return jdbc.queryForList(sql, params);
    }

    /** Promedio de distancia de las tareas completadas del usuario (preguntas 4 y 8). */
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
     * Agrupacion espacial (pregunta 5): K-Means sobre las zonas con tareas
     * pendientes DEL USUARIO. Devuelve, por grupo, el centro y un radio en
     * metros que encierra sus puntos (distancia maxima al centro + 25%,
     * minimo 400 m) para dibujar circulos correctos en el mapa.
     */
    public List<Map<String, Object>> clustersPendientes(int idUsuario, int k) {
        String sql = """
                WITH pendientes AS (
                    SELECT t.id_tarea, s.nombre, s.ubicacion,
                           ST_ClusterKMeans(s.ubicacion, :k) OVER () AS cluster_id
                    FROM tarea t
                    JOIN sector s ON s.id_sector = t.id_sector
                    WHERE t.completada = FALSE AND t.id_usuario = :idUsuario
                ), grupos AS (
                    SELECT cluster_id,
                           COUNT(*) AS tareas_pendientes,
                           STRING_AGG(DISTINCT nombre, ' | ') AS sectores,
                           ST_Centroid(ST_Collect(ubicacion)) AS centro
                    FROM pendientes
                    GROUP BY cluster_id
                )
                SELECT g.cluster_id, g.tareas_pendientes, g.sectores,
                       ST_Y(g.centro) AS latitud_centro,
                       ST_X(g.centro) AS longitud_centro,
                       ROUND(GREATEST(400,
                             MAX(ST_Distance(g.centro::geography,
                                             p.ubicacion::geography)) * 1.25)::numeric, 0)
                       AS radio_metros
                FROM grupos g
                JOIN pendientes p USING (cluster_id)
                GROUP BY g.cluster_id, g.tareas_pendientes, g.sectores, g.centro
                ORDER BY g.tareas_pendientes DESC
                """;
        var params = new MapSqlParameterSource()
                .addValue("idUsuario", idUsuario)
                .addValue("k", k);
        return jdbc.queryForList(sql, params);
    }
}
