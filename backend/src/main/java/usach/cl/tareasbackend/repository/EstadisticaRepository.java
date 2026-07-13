package usach.cl.tareasbackend.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

/**
 * Consultas espaciales PostGIS que responden las 8 preguntas del enunciado.
 * Son las mismas consultas de runStatements.sql, parametrizadas por usuario.
 * El cast ::geography hace que las distancias se calculen en METROS.
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
                ORDER BY tareas_completadas DESC
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("idUsuario", idUsuario));
    }

    /** P2: tarea pendiente mas cercana al usuario (operador KNN). */
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

    /** P3 y P7: sector con mas tareas completadas dentro de un radio (metros). */
    public List<Map<String, Object>> sectorConMasCompletadas(int idUsuario, double radioMetros) {
        String sql = """
                SELECT s.nombre AS sector, COUNT(t.id_tarea) AS tareas_completadas,
                       ROUND(ST_Distance(u.ubicacion::geography,
                                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                JOIN usuario u ON u.id_usuario = :idUsuario
                WHERE t.completada = TRUE
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

    /** P4: promedio de distancia de las tareas completadas del usuario. */
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

    /** P5: agrupacion espacial (K-Means) de las tareas pendientes. */
    public List<Map<String, Object>> clustersPendientes(int k) {
        String sql = """
                WITH pendientes AS (
                    SELECT t.id_tarea, s.nombre, s.ubicacion,
                           ST_ClusterKMeans(s.ubicacion, :k) OVER () AS cluster_id
                    FROM tarea t
                    JOIN sector s ON s.id_sector = t.id_sector
                    WHERE t.completada = FALSE
                )
                SELECT cluster_id,
                       COUNT(*) AS tareas_pendientes,
                       STRING_AGG(DISTINCT nombre, ', ') AS sectores,
                       ST_Y(ST_Centroid(ST_Collect(ubicacion))) AS latitud_centro,
                       ST_X(ST_Centroid(ST_Collect(ubicacion))) AS longitud_centro
                FROM pendientes
                GROUP BY cluster_id
                ORDER BY tareas_pendientes DESC
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("k", k));
    }

    /** P6: tareas completadas de cada usuario por sector. */
    public List<Map<String, Object>> tareasPorUsuarioYSector() {
        String sql = """
                SELECT u.nombre_usuario, s.nombre AS sector,
                       COUNT(t.id_tarea) AS tareas_completadas
                FROM tarea t
                JOIN usuario u ON u.id_usuario = t.id_usuario
                JOIN sector s ON s.id_sector = t.id_sector
                WHERE t.completada = TRUE
                GROUP BY u.nombre_usuario, s.nombre
                ORDER BY u.nombre_usuario, tareas_completadas DESC
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource());
    }

    /** P8: promedio de distancia de tareas completadas, por cada usuario. */
    public List<Map<String, Object>> promedioDistanciaTodos() {
        String sql = """
                SELECT u.nombre_usuario,
                       ROUND(AVG(ST_Distance(u.ubicacion::geography,
                                             s.ubicacion::geography))::numeric, 1)
                       AS promedio_distancia_metros
                FROM tarea t
                JOIN usuario u ON u.id_usuario = t.id_usuario
                JOIN sector s ON s.id_sector = t.id_sector
                WHERE t.completada = TRUE
                GROUP BY u.nombre_usuario
                ORDER BY u.nombre_usuario
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource());
    }
}