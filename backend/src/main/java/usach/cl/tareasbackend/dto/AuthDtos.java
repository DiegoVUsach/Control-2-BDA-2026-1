package usach.cl.tareasbackend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * DTOs de autenticacion. La "direccion geografica" del enunciado se
 * materializa como el punto (latitud/longitud) elegido en el mapa:
 * no se solicita direccion textual.
 */
public class AuthDtos {

    public record RegistroRequest(
            @NotBlank String nombreUsuario,
            @NotBlank String contrasena,
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
