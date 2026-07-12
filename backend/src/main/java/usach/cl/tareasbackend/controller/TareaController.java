package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.dto.TareaDtos.TareaRequest;
import usach.cl.tareasbackend.dto.TareaDtos.TareaResponse;
import usach.cl.tareasbackend.security.UsuarioAutenticado;
import usach.cl.tareasbackend.service.TareaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/tareas")
public class TareaController {

    private final TareaService tareaService;

    public TareaController(TareaService tareaService) {
        this.tareaService = tareaService;
    }

    /** Lista con filtros: /api/tareas?estado=pendiente|completada&buscar=palabra */
    @GetMapping
    public List<TareaResponse> listar(@AuthenticationPrincipal UsuarioAutenticado usuario,
                                      @RequestParam(required = false) String estado,
                                      @RequestParam(required = false) String buscar) {
        return tareaService.listar(usuario.id(), estado, buscar);
    }

    @PostMapping
    public ResponseEntity<TareaResponse> crear(@AuthenticationPrincipal UsuarioAutenticado usuario,
                                               @Valid @RequestBody TareaRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(tareaService.crear(usuario.id(), req));
    }

    @PutMapping("/{id}")
    public TareaResponse editar(@AuthenticationPrincipal UsuarioAutenticado usuario,
                                @PathVariable int id,
                                @Valid @RequestBody TareaRequest req) {
        return tareaService.editar(id, usuario.id(), req);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@AuthenticationPrincipal UsuarioAutenticado usuario,
                                         @PathVariable int id) {
        tareaService.eliminar(id, usuario.id());
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{id}/completar")
    public TareaResponse completar(@AuthenticationPrincipal UsuarioAutenticado usuario,
                                   @PathVariable int id) {
        return tareaService.completar(id, usuario.id());
    }
}