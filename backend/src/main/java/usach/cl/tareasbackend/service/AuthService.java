//nombre único, hash BCrypt al registrar,
// matches() al validar, mismo mensaje si falla usuario o clave.

package usach.cl.tareasbackend.service;

import usach.cl.tareasbackend.dto.AuthDtos.LoginRequest;
import usach.cl.tareasbackend.dto.AuthDtos.LoginResponse;
import usach.cl.tareasbackend.dto.AuthDtos.RegistroRequest;
import usach.cl.tareasbackend.repository.UsuarioRepository;
import usach.cl.tareasbackend.security.JwtUtil;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class AuthService {

    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    public AuthService(UsuarioRepository usuarioRepository,
                       PasswordEncoder passwordEncoder,
                       JwtUtil jwtUtil) {
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
    }

    /** Registra al usuario hasheando su contrasena con BCrypt. */
    public int registrar(RegistroRequest req) {
        if (usuarioRepository.existeNombre(req.nombreUsuario())) {
            throw new IllegalArgumentException("El nombre de usuario ya existe");
        }
        if (req.latitud() < -90 || req.latitud() > 90
                || req.longitud() < -180 || req.longitud() > 180) {
            throw new IllegalArgumentException("Coordenadas fuera de rango");
        }
        String hash = passwordEncoder.encode(req.contrasena());
        return usuarioRepository.insertar(req.nombreUsuario(), hash,
                req.direccion(), req.latitud(), req.longitud());
    }

    /** Valida credenciales y genera el JWT. */
    public LoginResponse login(LoginRequest req) {
        Map<String, Object> usuario = usuarioRepository
                .buscarPorNombre(req.nombreUsuario())
                .orElseThrow(() -> new BadCredentialsException("Credenciales invalidas"));

        String hash = (String) usuario.get("contrasena");
        if (!passwordEncoder.matches(req.contrasena(), hash)) {
            throw new BadCredentialsException("Credenciales invalidas");
        }
        int id = (Integer) usuario.get("id_usuario");
        String nombre = (String) usuario.get("nombre_usuario");
        return new LoginResponse(jwtUtil.generarToken(id, nombre), id, nombre);
    }
}