package com.example.demo.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletRequest;
import com.example.demo.dto.AuthResponse;
import com.example.demo.dto.LoginRequest;
import com.example.demo.repositories.UsuarioRepository;
import com.example.demo.services.JwtService;
import com.example.demo.entities.Usuario;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin("*")
public class AuthController {

    @Autowired
    private JwtService jwtService;

    @Autowired
    private UsuarioRepository usuarioRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest req, HttpServletRequest request) {
        System.out.println(">>> PETICIÓN DE LOGIN RECIBIDA. Username: " + (req != null ? req.getUsername() : "null"));
        if (req == null || req.getUsername() == null) {
            return ResponseEntity.badRequest().body("Error: No enviaste el JSON en el Body");
        }

        Usuario user = usuarioRepository.findByUsername(req.getUsername());
        if (user != null && passwordEncoder.matches(req.getPassword(), user.getPassword())) {
            String token = jwtService.createToken(user.getUsername());
            return ResponseEntity.ok(new AuthResponse(token));
        }

        return ResponseEntity.status(401).body("Credenciales incorrectas");
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody com.example.demo.dto.RegisterRequest req) {
        try {
            String encoded = passwordEncoder.encode(req.getPassword());
            Double lat = req.getLatitude();
            Double lon = req.getLongitude();
            if (lat == null || lon == null) {
                // Si no se proveen coordenadas, usamos un punto por defecto (0,0)
                lat = 0.0;
                lon = 0.0;
            }
            usuarioRepository.saveWithLocation(req.getUsername(), encoded, lon, lat);
            return ResponseEntity.ok("Usuario registrado exitosamente");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error al registrar: " + e.getMessage());
        }
    }
}