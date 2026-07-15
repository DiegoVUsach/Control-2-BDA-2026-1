package usach.cl.tareasbackend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Cuerpo para crear un sector desde la aplicacion:
 * nombre + punto elegido con GPS o clic en el mapa.
 */
public record SectorRequest(
        @NotBlank String nombre,
        @NotNull Double latitud,
        @NotNull Double longitud) {
}
