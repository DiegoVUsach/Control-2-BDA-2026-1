package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.dto.SectorDto;
import usach.cl.tareasbackend.repository.SectorRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
}