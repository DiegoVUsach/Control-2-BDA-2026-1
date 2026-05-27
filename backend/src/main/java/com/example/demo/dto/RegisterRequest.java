package com.example.demo.dto;

import lombok.Data;

@Data
public class RegisterRequest {
    private String username;
    private String password;
    // Coordenadas en WGS84 (latitud, longitud)
    private Double latitude;
    private Double longitude;
}
