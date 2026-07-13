//el "quién es" que viaja por la aplicación tras validar el token.

package usach.cl.tareasbackend.security;

public record UsuarioAutenticado(int id, String nombreUsuario) {}