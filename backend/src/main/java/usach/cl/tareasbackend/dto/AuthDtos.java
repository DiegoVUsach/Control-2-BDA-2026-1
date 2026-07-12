//records de entrada/salida con validación declarativa.

package usach.cl.tareasbackend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * DTOs de autenticacion (registro y login).
 */
public class AuthDtos {

    public record RegistroRequest(
            @NotBlank String nombreUsuario,
            @NotBlank String contrasena,
            @NotBlank String direccion,
            @NotNull Double latitud,
            @NotNull Double longitud) {
    }

    public record LoginRequest(
            @NotBlank String nombreUsuario,
            @NotBlank String contrasena) {
    }

    public record LoginResponse(String token, int id, String nombreUsuario) {
    }
}