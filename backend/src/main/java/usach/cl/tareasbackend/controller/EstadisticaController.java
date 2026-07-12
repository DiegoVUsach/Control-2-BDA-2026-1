package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.repository.EstadisticaRepository;
import usach.cl.tareasbackend.security.UsuarioAutenticado;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * Endpoints que responden las 8 preguntas del enunciado con PostGIS.
 */
@RestController
@RequestMapping("/api/estadisticas")
public class EstadisticaController {

    private final EstadisticaRepository repo;

    public EstadisticaController(EstadisticaRepository repo) {
        this.repo = repo;
    }

    /** P1 */
    @GetMapping("/tareas-por-sector")
    public List<Map<String, Object>> tareasPorSector(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.tareasPorSector(u.id());
    }

    /** P2 */
    @GetMapping("/tarea-mas-cercana")
    public List<Map<String, Object>> tareaMasCercana(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.tareaMasCercana(u.id());
    }

    /** P3 (radioKm=2) y P7 (radioKm=5) */
    @GetMapping("/sector-mas-completadas")
    public List<Map<String, Object>> sectorMasCompletadas(
            @AuthenticationPrincipal UsuarioAutenticado u,
            @RequestParam(defaultValue = "2") double radioKm) {
        return repo.sectorConMasCompletadas(u.id(), radioKm * 1000);
    }

    /** P4 */
    @GetMapping("/promedio-distancia")
    public List<Map<String, Object>> promedioDistancia(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.promedioDistancia(u.id());
    }

    /** P5 */
    @GetMapping("/clusters-pendientes")
    public List<Map<String, Object>> clustersPendientes(
            @RequestParam(defaultValue = "3") int k) {
        return repo.clustersPendientes(k);
    }

    /** P6 */
    @GetMapping("/tareas-por-usuario-sector")
    public List<Map<String, Object>> tareasPorUsuarioYSector() {
        return repo.tareasPorUsuarioYSector();
    }

    /** P8 */
    @GetMapping("/promedio-distancia-usuarios")
    public List<Map<String, Object>> promedioDistanciaTodos() {
        return repo.promedioDistanciaTodos();
    }
}