package com.example.demo.services;

import com.example.demo.entities.Sector;
import com.example.demo.repositories.SectorRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class SectorService {

    @Autowired
    private SectorRepository sectorRepository;

    public List<Sector> obtenerTodosLosSectores() {
        return sectorRepository.findAll();
    }

    public Sector guardarSector(Sector sector) {
        return sectorRepository.save(sector);
    }
}