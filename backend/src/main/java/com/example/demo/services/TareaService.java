package com.example.demo.services;

import com.example.demo.entities.Tarea;
import com.example.demo.repositories.TareaRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.List;
import com.example.demo.entities.Usuario;


/*@Service
public class TareaService {

    @Autowired
    private TareaRepository tareaRepository;

    // --- CRUD SEGURO (Solo opera sobre las cosas del usuario) ---

    public Tarea crearTarea(Tarea tarea) {
        return tareaRepository.save(tarea);
    }

    public Tarea modificarTarea(Long idTarea, Tarea datosNuevos, Long idUsuarioAutenticado) {
        Tarea tareaExistente = tareaRepository.findById(idTarea)
                .orElseThrow(() -> new RuntimeException("Tarea no encontrada"));

        // Validación estricta confirmada por el ayudante: Solo el dueño edita
        if (!tareaExistente.getUsuario().getIdUsuario().equals(idUsuarioAutenticado)) {
            throw new RuntimeException("No tienes permisos para modificar esta tarea");
        }

        tareaExistente.setTitulo(datosNuevos.getTitulo());
        tareaExistente.setDescripcion(datosNuevos.getDescripcion());
        tareaExistente.setFechaVencimiento(datosNuevos.getFechaVencimiento());
        tareaExistente.setSector(datosNuevos.getSector());
        
        return tareaRepository.save(tareaExistente);
    }

    public void eliminarTarea(Long idTarea, Long idUsuarioAutenticado) {
        Tarea tareaExistente = tareaRepository.findById(idTarea)
                .orElseThrow(() -> new RuntimeException("Tarea no encontrada"));

        // Validación estricta: Solo el dueño elimina
        if (!tareaExistente.getUsuario().getIdUsuario().equals(idUsuarioAutenticado)) {
            throw new RuntimeException("No tienes permisos para eliminar esta tarea");
        }

        tareaRepository.delete(tareaExistente);
    }

    public Tarea marcarComoCompletada(Long idTarea, Long idUsuarioAutenticado) {
        Tarea tareaExistente = tareaRepository.findById(idTarea)
                .orElseThrow(() -> new RuntimeException("Tarea no encontrada"));

        if (!tareaExistente.getUsuario().getIdUsuario().equals(idUsuarioAutenticado)) {
            throw new RuntimeException("No tienes permisos sobre esta tarea");
        }

        tareaExistente.setCompletada(true);
        return tareaRepository.save(tareaExistente);
    }

    // --- BÚSQUEDA Y FILTROS ---
    public List<Tarea> buscarTareas(boolean completada, String keyword) {
        return tareaRepository.buscarPorEstadoYPalabraClave(completada, keyword);
    }

    // --- MÓDULO ANALÍTICO POSTGIS (Punto 6 del PDF) ---

    public List<Object[]> obtenerTareasCompletadasPorUsuarioYSector() {
        return tareaRepository.contarTareasCompletadasPorUsuarioYSector();
    }

    public Tarea obtenerTareaMasCercanaPendiente(Long idUsuario) {
        return tareaRepository.encontrarTareaMasCercanaPendiente(idUsuario);
    }

    public List<Object[]> obtenerSectorMasActivoEnRadio(Long idUsuario, double radioKm) {
        // Convertimos kilómetros a metros para la función ST_DWithin
        double metros = radioKm * 1000.0;
        return tareaRepository.encontrarSectorMasActivoEnRadio(idUsuario, metros);
    }

    public Double obtenerPromedioDistanciaTareasCompletadas(Long idUsuario) {
        return tareaRepository.calcularPromedioDistanciaTareasCompletadas(idUsuario);
    }
} */