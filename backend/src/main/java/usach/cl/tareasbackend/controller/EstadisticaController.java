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
 * Estadisticas espaciales del enunciado.
 * Salvo el reporte agregado, todas son PRIVADAS: cada respuesta se calcula
 * exclusivamente con las tareas del usuario autenticado (el id sale del
 * token, nunca de la URL). Todas exigen JWT (SecurityConfig).
 */
@RestController
@RequestMapping("/api/estadisticas")
public class EstadisticaController {

    private final EstadisticaRepository repo;

    public EstadisticaController(EstadisticaRepository repo) {
        this.repo = repo;
    }

    /** P1: ¿Cuantas tareas ha hecho el usuario por sector? */
    @GetMapping("/tareas-por-sector")
    public List<Map<String, Object>> tareasPorSector(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.tareasPorSector(u.id());
    }

    /** P2: ¿Cual es la tarea pendiente mas cercana al usuario? */
    @GetMapping("/tarea-mas-cercana")
    public List<Map<String, Object>> tareaMasCercana(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.tareaMasCercana(u.id());
    }

    /** P3 y P7: ¿Cual es el sector con mas tareas completadas en un radio dado? (2 o 5 km) */
    @GetMapping("/sector-mas-completadas")
    public List<Map<String, Object>> sectorMasCompletadas(
            @AuthenticationPrincipal UsuarioAutenticado u,
            @RequestParam(defaultValue = "2") double radioKm) {
        if (radioKm <= 0 || radioKm > 100) {
            throw new IllegalArgumentException("El radio debe estar entre 0 y 100 km");
        }
        return repo.sectorConMasCompletadas(u.id(), radioKm * 1000);
    }

    /** P4 y P8: ¿Cual es el promedio de distancia de las tareas completadas? */
    @GetMapping("/promedio-distancia")
    public List<Map<String, Object>> promedioDistancia(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.promedioDistancia(u.id());
    }

    /** P5: ¿En que zonas se concentran las tareas pendientes? (agrupacion espacial) */
    @GetMapping("/clusters-pendientes")
    public List<Map<String, Object>> clustersPendientes(
            @AuthenticationPrincipal UsuarioAutenticado u,
            @RequestParam(defaultValue = "3") int k) {
        if (k < 1 || k > 10) {
            throw new IllegalArgumentException("k debe estar entre 1 y 10");
        }
        return repo.clustersPendientes(u.id(), k);
    }

    /** Detalle por zona de P5 (cada zona con su cantidad y su grupo), para el mapa. */
    @GetMapping("/pendientes-por-zona")
    public List<Map<String, Object>> pendientesPorZona(
            @AuthenticationPrincipal UsuarioAutenticado u,
            @RequestParam(defaultValue = "3") int k) {
        if (k < 1 || k > 10) {
            throw new IllegalArgumentException("k debe estar entre 1 y 10");
        }
        return repo.pendientesPorZona(u.id(), k);
    }

    /**
     * Apoyo visual de P3 y P7: zonas con tareas completadas del usuario, con
     * distancia y marca de si caen dentro de los radios de 2 y 5 km. Sirve para
     * dibujar en el mapa por que gana una zona y no otra.
     */
    @GetMapping("/completadas-por-zona")
    public List<Map<String, Object>> completadasPorZona(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.completadasPorZona(u.id());
    }

    /**
     * P6: ¿Cuantas tareas ha realizado CADA usuario por sector?
     * Reporte agregado (solo conteos, sin contenido de tareas ajenas).
     * Requiere sesion iniciada como cualquier otro endpoint.
     */
    @GetMapping("/tareas-por-usuario-sector")
    public List<Map<String, Object>> tareasPorUsuarioYSector(
            @AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.tareasPorUsuarioYSector();
    }
}
