package usach.cl.tareasbackend.controller;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import usach.cl.tareasbackend.dto.SectorDto;
import usach.cl.tareasbackend.dto.SectorRequest;
import usach.cl.tareasbackend.repository.SectorRepository;

import java.util.List;

@RestController
@RequestMapping("/api/sectores")
public class SectorController {

    private final SectorRepository sectorRepository;

    public SectorController(SectorRepository sectorRepository) {
        this.sectorRepository = sectorRepository;
    }

    @GetMapping
    public List<SectorDto> listar() {
        return sectorRepository.listar();
    }

    /** Crear un sector desde la app (nombre + punto por GPS o clic en el mapa). */
    @PostMapping
    public ResponseEntity<SectorDto> crear(@Valid @RequestBody SectorRequest req) {
        String nombre = req.nombre().trim();
        if (sectorRepository.existeNombre(nombre)) {
            throw new IllegalArgumentException("Ya existe un sector con ese nombre");
        }
        int id = sectorRepository.insertar(nombre, req.latitud(), req.longitud());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new SectorDto(id, nombre, req.latitud(), req.longitud()));
    }
}
