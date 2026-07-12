//mapea las dos rutas públicas.

package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.dto.AuthDtos.LoginRequest;
import usach.cl.tareasbackend.dto.AuthDtos.LoginResponse;
import usach.cl.tareasbackend.dto.AuthDtos.RegistroRequest;
import usach.cl.tareasbackend.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    public ResponseEntity<Map<String, Object>> registrar(@Valid @RequestBody RegistroRequest req) {
        int id = authService.registrar(req);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("id", id, "nombreUsuario", req.nombreUsuario(),
                        "mensaje", "Usuario registrado. Ahora puede iniciar sesion."));
    }

    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }
}