package usach.cl.tareasbackend.repository;

import usach.cl.tareasbackend.dto.NotificacionDto;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * Acceso a datos de notificaciones. Las notificaciones son generadas por
 * el trigger trg_notificar_vencimiento definido en dbCreate.sql.
 */
@Repository
public class NotificacionRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public NotificacionRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<NotificacionDto> listarPorUsuario(int idUsuario) {
        String sql = """
                SELECT id_notificacion, mensaje, fecha_creacion, leida, id_tarea
                FROM notificacion
                WHERE id_usuario = :idUsuario
                ORDER BY fecha_creacion DESC
                """;
        return jdbc.query(sql, new MapSqlParameterSource("idUsuario", idUsuario),
                (rs, i) -> new NotificacionDto(
                        rs.getInt("id_notificacion"),
                        rs.getString("mensaje"),
                        rs.getTimestamp("fecha_creacion").toLocalDateTime(),
                        rs.getBoolean("leida"),
                        rs.getInt("id_tarea")));
    }

    /**
     * Genera notificaciones para las tareas pendientes del usuario que
     * vencen dentro de :dias dias y que aun no tienen notificacion.
     * Complementa al trigger para tareas cuyo vencimiento "se acerco"
     * con el paso del tiempo.
     */
    public int generarPorVencer(int idUsuario, int dias) {
        String sql = """
                INSERT INTO notificacion (mensaje, id_usuario, id_tarea)
                SELECT 'La tarea "' || t.titulo || '" vence el ' ||
                       TO_CHAR(t.fecha_vencimiento, 'DD-MM-YYYY'),
                       t.id_usuario, t.id_tarea
                FROM tarea t
                WHERE t.id_usuario = :idUsuario
                  AND t.completada = FALSE
                  AND t.fecha_vencimiento <= CURRENT_DATE + :dias
                  AND NOT EXISTS (SELECT 1 FROM notificacion n
                                  WHERE n.id_tarea = t.id_tarea)
                """;
        var params = new MapSqlParameterSource()
                .addValue("idUsuario", idUsuario)
                .addValue("dias", dias);
        return jdbc.update(sql, params);
    }

    public int marcarLeida(int idNotificacion, int idUsuario) {
        String sql = """
                UPDATE notificacion SET leida = TRUE
                WHERE id_notificacion = :id AND id_usuario = :idUsuario
                """;
        var params = new MapSqlParameterSource()
                .addValue("id", idNotificacion)
                .addValue("idUsuario", idUsuario);
        return jdbc.update(sql, params);
    }
}