package usach.cl.tareasbackend.service;

import usach.cl.tareasbackend.dto.TareaDtos.TareaRequest;
import usach.cl.tareasbackend.dto.TareaDtos.TareaResponse;
import usach.cl.tareasbackend.repository.TareaRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.NoSuchElementException;

@Service
public class TareaService {

    private final TareaRepository tareaRepository;

    public TareaService(TareaRepository tareaRepository) {
        this.tareaRepository = tareaRepository;
    }

    public List<TareaResponse> listar(int idUsuario, String estado, String buscar) {
        return tareaRepository.listar(idUsuario, estado, buscar);
    }

    public TareaResponse crear(int idUsuario, TareaRequest req) {
        int id = tareaRepository.insertar(idUsuario, req.titulo(),
                req.descripcion(), req.fechaVencimiento(), req.idSector());
        return obtener(id, idUsuario);
    }

    public TareaResponse editar(int idTarea, int idUsuario, TareaRequest req) {
        int filas = tareaRepository.actualizar(idTarea, idUsuario, req.titulo(),
                req.descripcion(), req.fechaVencimiento(), req.idSector());
        if (filas == 0) {
            throw new NoSuchElementException("Tarea no encontrada");
        }
        return obtener(idTarea, idUsuario);
    }

    public void eliminar(int idTarea, int idUsuario) {
        if (tareaRepository.eliminar(idTarea, idUsuario) == 0) {
            throw new NoSuchElementException("Tarea no encontrada");
        }
    }

    public TareaResponse completar(int idTarea, int idUsuario) {
        tareaRepository.marcarCompletada(idTarea, idUsuario);
        return obtener(idTarea, idUsuario);
    }

    private TareaResponse obtener(int idTarea, int idUsuario) {
        return tareaRepository.buscarPorIdYUsuario(idTarea, idUsuario)
                .orElseThrow(() -> new NoSuchElementException("Tarea no encontrada"));
    }
}