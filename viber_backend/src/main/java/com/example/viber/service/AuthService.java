package com.example.viber.service;

import java.util.Base64;
import java.util.Map;
import java.util.Optional;

import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import com.example.viber.dto.GoogleAuthRequest;
import com.example.viber.dto.LoginRequest;
import com.example.viber.dto.RegisterRequest;
import com.example.viber.model.User;
import com.example.viber.model.User.AuthProvider;
import com.example.viber.repository.UserRepository;
import com.example.viber.utils.JwtUtil;

/**
 * Lógica de negocio de autenticación.
 *
 * Soporta tres flujos:
 *  - Registro clásico (username + email + password con BCrypt)
 *  - Login clásico
 *  - Login/registro con Google: valida el idToken localmente (Base64 decode + comprobación de issuer
 *    y audience), luego vincula o crea la cuenta según si el email ya existe.
 *
 * El método {@code changePassword} permite a cuentas Google añadir contraseña;
 * el proveedor se actualiza automáticamente a BOTH.
 */
@Service
public class AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JwtUtil jwtUtil;

    @Value("${google.client-id}")
    private String googleClientId;

    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    // ── Registro clásico ───────────────────────────────────────────────────

    public Map<String, String> register(RegisterRequest request) {
        if (userRepository.findByUsername(request.getUsername()).isPresent()) {
            throw new RuntimeException("El nombre de usuario ya está en uso");
        }
        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new RuntimeException("El email ya está registrado");
        }

        User user = new User();
        user.setUsername(request.getUsername());
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setAuthProvider(AuthProvider.LOCAL);

        userRepository.save(user);
        return authResponse(user);
    }

    // ── Login clásico ──────────────────────────────────────────────────────

    public Map<String, String> login(LoginRequest request) {
        User user = userRepository.findByUsername(request.getUsername())
            .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

        if (!user.canLoginWithPassword()) {
            throw new RuntimeException(
                "Esta cuenta usa Google Sign-In. Entra con Google o añade una contraseña desde Ajustes → Seguridad."
            );
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new RuntimeException("Contraseña incorrecta");
        }

        return authResponse(user);
    }

    // ── Login / Registro con Google ────────────────────────────────────────

    public Map<String, String> loginWithGoogle(GoogleAuthRequest request) {
        JSONObject claims = decodeGoogleIdToken(request.getIdToken());

        String googleId   = claims.getString("sub");
        String email      = claims.getString("email");
        String name       = claims.optString("name", "");
        String pictureUrl = claims.optString("picture", "");

        // Validar que el token es para nuestra app
        String aud = claims.get("aud").toString();
        if (!aud.contains(googleClientId)) {
            throw new RuntimeException("Token de Google no válido para esta aplicación");
        }

        // Validar expiración
        long exp = claims.getLong("exp");
        if (exp < System.currentTimeMillis() / 1000) {
            throw new RuntimeException("Token de Google expirado");
        }

        // 1. Buscar por googleId
        Optional<User> byGoogleId = userRepository.findByGoogleId(googleId);
        if (byGoogleId.isPresent()) {
            return authResponse(byGoogleId.get());
        }

        // 2. Buscar por email — vincular cuenta existente
        Optional<User> byEmail = userRepository.findByEmail(email);
        if (byEmail.isPresent()) {
            User existing = byEmail.get();
            existing.setGoogleId(googleId);
            existing.setAuthProvider(AuthProvider.BOTH);
            if (existing.getAvatarUrl() == null || existing.getAvatarUrl().isBlank()) {
                existing.setAvatarUrl(pictureUrl);
            }
            userRepository.save(existing);
            return authResponse(existing);
        }

        // 3. Usuario nuevo
        User newUser = new User();
        newUser.setEmail(email);
        newUser.setGoogleId(googleId);
        newUser.setAuthProvider(AuthProvider.GOOGLE);
        newUser.setDisplayName(name);
        newUser.setAvatarUrl(pictureUrl);
        newUser.setUsername(generateUniqueUsername(name));

        userRepository.save(newUser);
        return authResponse(newUser);
    }

    private Map<String, String> authResponse(User user) {
        return Map.of(
            "token", jwtUtil.generateToken(user),
            "role",  user.getRole().name()
        );
    }

    // ── Decodificar idToken de Google (JWT) ────────────────────────────────

    private JSONObject decodeGoogleIdToken(String idToken) {
        try {
            String[] parts = idToken.split("\\.");
            if (parts.length < 2) {
                throw new RuntimeException("Token de Google malformado");
            }

            // Añadir padding Base64 si es necesario
            String payload = parts[1];
            int mod = payload.length() % 4;
            if (mod != 0) payload += "=".repeat(4 - mod);

            String payloadJson = new String(Base64.getUrlDecoder().decode(payload));
            JSONObject claims = new JSONObject(payloadJson);

            // Validar issuer
            String iss = claims.optString("iss", "");
            if (!iss.equals("accounts.google.com") && !iss.equals("https://accounts.google.com")) {
                throw new RuntimeException("Token no emitido por Google");
            }

            return claims;

        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException("Error al procesar el token de Google: " + e.getMessage());
        }
    }

    // ── Generador de username único ────────────────────────────────────────

    private String generateUniqueUsername(String displayName) {
        if (displayName == null || displayName.isBlank()) displayName = "user";

        String base = displayName
            .toLowerCase()
            .replaceAll("[^a-z0-9]", "_")
            .replaceAll("_+", "_")
            .replaceAll("^_|_$", "");

        if (base.length() > 30) base = base.substring(0, 30);
        if (base.isBlank()) base = "user";

        if (userRepository.findByUsername(base).isEmpty()) return base;

        int suffix = 2;
        while (true) {
            String candidate = base + "_" + suffix;
            if (userRepository.findByUsername(candidate).isEmpty()) return candidate;
            suffix++;
        }
    }

    public void changePassword(String username, String currentPassword, String newPassword) {
        User user = userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

        // Si ya tiene contraseña, verificar la actual
        if (user.hasPassword()) {
            if (currentPassword == null || currentPassword.isBlank()) {
                throw new RuntimeException("Debes introducir tu contraseña actual");
            }
            if (!passwordEncoder.matches(currentPassword, user.getPassword())) {
                throw new RuntimeException("La contraseña actual no es correcta");
            }
        }

        if (newPassword == null || newPassword.length() < 6) {
            throw new RuntimeException("La nueva contraseña debe tener al menos 6 caracteres");
        }

        user.setPassword(passwordEncoder.encode(newPassword));

        // Si era cuenta Google, ahora puede usar ambos métodos
        if (user.getAuthProvider() == User.AuthProvider.GOOGLE) {
            user.setAuthProvider(User.AuthProvider.BOTH);
        }

        userRepository.save(user);
    }
}