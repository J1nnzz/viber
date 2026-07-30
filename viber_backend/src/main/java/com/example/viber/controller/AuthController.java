package com.example.viber.controller;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.viber.dto.ChangePasswordRequest;
import com.example.viber.dto.GoogleAuthRequest;
import com.example.viber.dto.LoginRequest;
import com.example.viber.dto.RegisterRequest;
import com.example.viber.exception.NotFoundException;
import com.example.viber.repository.UserRepository;
import com.example.viber.service.AuthService;
import com.example.viber.utils.JwtUtil;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

/**
 * Endpoints de autenticación: registro, login clásico, login con Google y cambio de contraseña.
 * Todos los métodos son públicos (no requieren JWT previo salvo /change-password y /me).
 */
@Tag(name = "Autenticación", description = "Registro, login y gestión de contraseña")
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    @Autowired private AuthService    authService;
    @Autowired private JwtUtil        jwtUtil;
    @Autowired private UserRepository userRepository;

    @Operation(summary = "Registrar nuevo usuario")
    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest request) {
        return ResponseEntity.ok(authService.register(request));
    }

    @Operation(summary = "Iniciar sesión con usuario y contraseña")
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    @Operation(summary = "Iniciar sesión con Google OAuth")
    @PostMapping("/google")
    public ResponseEntity<?> googleAuth(@RequestBody GoogleAuthRequest request) {
        return ResponseEntity.ok(authService.loginWithGoogle(request));
    }

    @Operation(summary = "Obtener rol del usuario autenticado")
    @GetMapping("/me")
    public ResponseEntity<?> me(@RequestHeader("Authorization") String authHeader) {
        String token = authHeader.replace("Bearer ", "");
        if (!jwtUtil.validateToken(token)) {
            return ResponseEntity.status(401).body(Map.of("error", "Token inválido"));
        }
        String username = jwtUtil.getUsernameFromToken(token);
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));
        return ResponseEntity.ok(Map.of(
                "username", user.getUsername(),
                "role",     user.getRole().name()
        ));
    }

    @Operation(summary = "Cambiar contraseña del usuario autenticado")
    @PostMapping("/change-password")
    public ResponseEntity<?> changePassword(
            @RequestHeader("Authorization") String authHeader,
            @RequestBody ChangePasswordRequest request) {
        String token    = authHeader.replace("Bearer ", "");
        String username = jwtUtil.getUsernameFromToken(token);
        authService.changePassword(username, request.getCurrentPassword(), request.getNewPassword());
        return ResponseEntity.ok(Map.of("message", "Contraseña actualizada correctamente"));
    }
}
