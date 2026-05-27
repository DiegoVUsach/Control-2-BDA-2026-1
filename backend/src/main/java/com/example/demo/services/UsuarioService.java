package com.example.demo.services;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.example.demo.dto.AuthResponse;
import com.example.demo.dto.LoginRequest;
import com.example.demo.repositories.UsuarioRepository;
import com.example.demo.entities.Usuario;

@Service
public class UsuarioService {

    @Autowired
    private UsuarioRepository usuarioRepository;

    // PasswordEncoder compara passwords de forma segura.
    // Aunque usamos NoOpPasswordEncoder (texto plano) por simplicidad,
    // la estructura esta lista para usar BCrypt en produccion.
    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtService jwtService;

    // Flujo de login:
    // 1. Busca el usuario por nombre en la BD
    // 2. Compara la password recibida con la guardada
    // 3. Si coinciden, genera un token JWT con username + rol
    // 4. Si no coinciden, lanza excepcion (el controller la atrapa)
    public AuthResponse login(LoginRequest request) {
        Usuario usuario = usuarioRepository.findByUsername(request.getUsername());
        if (usuario != null && passwordEncoder.matches(request.getPassword(), usuario.getPassword())) {
            String token = jwtService.createToken(usuario.getUsername());
            return new AuthResponse(token);
        }
        throw new RuntimeException("Credenciales invalidas");
    }

    // Flujo de registro:
    // 1. Encripta la password (con NoOp queda igual, con BCrypt la hashea)
    // 2. Asigna rol USER por defecto si no viene uno
    // 3. Guarda en la BD
    public void register(Usuario usuario) {
        usuario.setPassword(passwordEncoder.encode(usuario.getPassword()));
        usuarioRepository.save(usuario);
    }
}