package usach.cl.tareasbackend.repository;

import usach.cl.tareasbackend.dto.TareaDtos.TareaResponse;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * Acceso a datos de tareas con SQL explicito (sin ORM).
 * Todas las operaciones filtran por id_usuario: un usuario solo puede
 * ver y modificar SUS tareas (autorizacion a nivel de datos).
 */
@Repository
public class TareaRepository {

    private final NamedParameterJdbcTemplate jdbc;

    private static final String SELECT_BASE = """
            SELECT t.id_tarea, t.titulo, t.descripcion, t.fecha_vencimiento,
                   t.completada, t.fecha_completada,
                   s.id_sector, s.nombre AS nombre_sector,
                   ST_Y(s.ubicacion) AS latitud_sector,
                   ST_X(s.ubicacion) AS longitud_sector
            FROM tarea t
            JOIN sector s ON s.id_sector = t.id_sector
            """;

    private static final RowMapper<TareaResponse> MAPPER = (rs, i) -> {
        Timestamp fc = rs.getTimestamp("fecha_completada");
        return new TareaResponse(
                rs.getInt("id_tarea"),
                rs.getString("titulo"),
                rs.getString("descripcion"),
                rs.getDate("fecha_vencimiento").toLocalDate(),
                rs.getBoolean("completada"),
                fc != null ? fc.toLocalDateTime() : null,
                rs.getInt("id_sector"),
                rs.getString("nombre_sector"),
                rs.getDouble("latitud_sector"),
                rs.getDouble("longitud_sector"));
    };

    public TareaRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Lista las tareas del usuario con filtros opcionales:
     * - estado: "pendiente" | "completada" | null (todas)
     * - buscar: palabra clave en titulo o descripcion (ILIKE parametrizado)
     */
    public List<TareaResponse> listar(int idUsuario, String estado, String buscar) {
        StringBuilder sql = new StringBuilder(SELECT_BASE)
                .append(" WHERE t.id_usuario = :idUsuario ");
        var params = new MapSqlParameterSource("idUsuario", idUsuario);

        if ("pendiente".equalsIgnoreCase(estado)) {
            sql.append(" AND t.completada = FALSE ");
        } else if ("completada".equalsIgnoreCase(estado)) {
            sql.append(" AND t.completada = TRUE ");
        }
        if (buscar != null && !buscar.isBlank()) {
            sql.append(" AND (t.titulo ILIKE :patron OR t.descripcion ILIKE :patron) ");
            params.addValue("patron", "%" + buscar.trim() + "%");
        }
        sql.append(" ORDER BY t.completada ASC, t.fecha_vencimiento ASC ");
        return jdbc.query(sql.toString(), params, MAPPER);
    }

    public Optional<TareaResponse> buscarPorIdYUsuario(int idTarea, int idUsuario) {
        String sql = SELECT_BASE + " WHERE t.id_tarea = :idTarea AND t.id_usuario = :idUsuario";
        var params = new MapSqlParameterSource()
                .addValue("idTarea", idTarea)
                .addValue("idUsuario", idUsuario);
        return jdbc.query(sql, params, MAPPER).stream().findFirst();
    }

    public int insertar(int idUsuario, String titulo, String descripcion,
                        LocalDate fechaVencimiento, int idSector) {
        String sql = """
                INSERT INTO tarea (titulo, descripcion, fecha_vencimiento, id_usuario, id_sector)
                VALUES (:titulo, :descripcion, :fecha, :idUsuario, :idSector)
                RETURNING id_tarea
                """;
        var params = new MapSqlParameterSource()
                .addValue("titulo", titulo)
                .addValue("descripcion", descripcion)
                .addValue("fecha", fechaVencimiento)
                .addValue("idUsuario", idUsuario)
                .addValue("idSector", idSector);
        return jdbc.queryForObject(sql, params, Integer.class);
    }

    /** Edita titulo, descripcion, vencimiento y sector. Retorna filas afectadas. */
    public int actualizar(int idTarea, int idUsuario, String titulo, String descripcion,
                          LocalDate fechaVencimiento, int idSector) {
        String sql = """
                UPDATE tarea
                SET titulo = :titulo,
                    descripcion = :descripcion,
                    fecha_vencimiento = :fecha,
                    id_sector = :idSector
                WHERE id_tarea = :idTarea AND id_usuario = :idUsuario
                """;
        var params = new MapSqlParameterSource()
                .addValue("titulo", titulo)
                .addValue("descripcion", descripcion)
                .addValue("fecha", fechaVencimiento)
                .addValue("idSector", idSector)
                .addValue("idTarea", idTarea)
                .addValue("idUsuario", idUsuario);
        return jdbc.update(sql, params);
    }

    public int eliminar(int idTarea, int idUsuario) {
        String sql = "DELETE FROM tarea WHERE id_tarea = :idTarea AND id_usuario = :idUsuario";
        var params = new MapSqlParameterSource()
                .addValue("idTarea", idTarea)
                .addValue("idUsuario", idUsuario);
        return jdbc.update(sql, params);
    }

    public int marcarCompletada(int idTarea, int idUsuario) {
        String sql = """
                UPDATE tarea
                SET completada = TRUE, fecha_completada = NOW()
                WHERE id_tarea = :idTarea AND id_usuario = :idUsuario AND completada = FALSE
                """;
        var params = new MapSqlParameterSource()
                .addValue("idTarea", idTarea)
                .addValue("idUsuario", idUsuario);
        return jdbc.update(sql, params);
    }
}