package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.repository.UsuarioRepository;
import usach.cl.tareasbackend.security.UsuarioAutenticado;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.NoSuchElementException;

@RestController
@RequestMapping("/api/usuarios")
public class UsuarioController {

    private final UsuarioRepository usuarioRepository;

    public UsuarioController(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
    }

    /** Perfil del usuario autenticado con sus coordenadas (para el mapa). */
    @GetMapping("/me")
    public Map<String, Object> perfil(@AuthenticationPrincipal UsuarioAutenticado u) {
        return usuarioRepository.datosPerfil(u.id())
                .orElseThrow(() -> new NoSuchElementException("Usuario no encontrado"));
    }
}