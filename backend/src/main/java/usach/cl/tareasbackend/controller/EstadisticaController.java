package usach.cl.tareasbackend.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import usach.cl.tareasbackend.repository.EstadisticaRepository;
import usach.cl.tareasbackend.security.UsuarioAutenticado;

import java.util.List;
import java.util.Map;

/**
 * Estadisticas espaciales. Todas son PRIVADAS: cada respuesta se calcula
 * exclusivamente con las tareas del usuario autenticado (el id sale del
 * token, nunca de la URL). Las preguntas del enunciado formuladas "por cada
 * usuario" se responden con estas mismas rutas evaluadas por cada sesion.
 */
@RestController
@RequestMapping("/api/estadisticas")
public class EstadisticaController {

    private final EstadisticaRepository repo;

    public EstadisticaController(EstadisticaRepository repo) {
        this.repo = repo;
    }

    /** ¿Cuantas tareas ha hecho el usuario por sector? */
    @GetMapping("/tareas-por-sector")
    public List<Map<String, Object>> tareasPorSector(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.tareasPorSector(u.id());
    }

    /** ¿Cual es la tarea pendiente mas cercana al usuario? */
    @GetMapping("/tarea-mas-cercana")
    public List<Map<String, Object>> tareaMasCercana(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.tareaMasCercana(u.id());
    }

    /** ¿Cual es el sector con mas tareas completadas en un radio dado? (2 o 5 km) */
    @GetMapping("/sector-mas-completadas")
    public List<Map<String, Object>> sectorMasCompletadas(
            @AuthenticationPrincipal UsuarioAutenticado u,
            @RequestParam(defaultValue = "2") double radioKm) {
        return repo.sectorConMasCompletadas(u.id(), radioKm * 1000);
    }

    /** ¿Cual es el promedio de distancia de las tareas completadas? */
    @GetMapping("/promedio-distancia")
    public List<Map<String, Object>> promedioDistancia(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.promedioDistancia(u.id());
    }

    /** ¿En que zonas se concentran las tareas pendientes? (agrupacion espacial) */
    @GetMapping("/clusters-pendientes")
    public List<Map<String, Object>> clustersPendientes(
            @AuthenticationPrincipal UsuarioAutenticado u,
            @RequestParam(defaultValue = "3") int k) {
        return repo.clustersPendientes(u.id(), k);
    }
}
