package usach.cl.tareasbackend.dto;

import java.time.LocalDateTime;

/**
 * Notificacion de vencimiento de tarea.
 */
public record NotificacionDto(int idNotificacion, String mensaje,
                              LocalDateTime fechaCreacion, boolean leida,
                              int idTarea) {
}
