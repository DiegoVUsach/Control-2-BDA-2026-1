package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.dto.NotificacionDto;
import usach.cl.tareasbackend.repository.NotificacionRepository;
import usach.cl.tareasbackend.security.UsuarioAutenticado;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notificaciones")
public class NotificacionController {

    private final NotificacionRepository notificacionRepository;

    public NotificacionController(NotificacionRepository notificacionRepository) {
        this.notificacionRepository = notificacionRepository;
    }

    /**
     * Antes de listar, genera notificaciones para las tareas del usuario
     * que vencen en los proximos 3 dias (si aun no existen).
     */
    @GetMapping
    public List<NotificacionDto> listar(@AuthenticationPrincipal UsuarioAutenticado usuario) {
        notificacionRepository.generarPorVencer(usuario.id(), 3);
        return notificacionRepository.listarPorUsuario(usuario.id());
    }

    @PatchMapping("/{id}/leer")
    public void marcarLeida(@AuthenticationPrincipal UsuarioAutenticado usuario,
                            @PathVariable int id) {
        notificacionRepository.marcarLeida(id, usuario.id());
    }
}
