package com.example.demo.entities;

import jakarta.persistence.*;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Data;

import org.locationtech.jts.geom.Point;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "SECTORES")
public class Sector {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_sector")
    private Long idSector;

    @Column(name = "nombre_sector", length = 80, nullable = false)
    private String nombreSector;

    @Column(name = "ubicacion_spatial", columnDefinition = "geometry(Point,4326)", nullable = false)
    private Point ubicacionSpatial;
}