package usach.cl.tareasbackend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * DTOs de tareas.
 */
public class TareaDtos {

    /** Cuerpo para crear o editar una tarea. */
    public record TareaRequest(
            @NotBlank String titulo,
            String descripcion,
            @NotNull LocalDate fechaVencimiento,
            @NotNull Integer idSector) {
    }

    /** Respuesta con la tarea y los datos de su sector georreferenciado. */
    public record TareaResponse(
            int idTarea,
            String titulo,
            String descripcion,
            LocalDate fechaVencimiento,
            boolean completada,
            LocalDateTime fechaCompletada,
            int idSector,
            String nombreSector,
            double latitudSector,
            double longitudSector) {
    }
}
