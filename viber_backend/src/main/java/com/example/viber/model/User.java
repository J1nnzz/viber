package com.example.viber.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Entidad principal de usuario.
 * Soporta tres métodos de autenticación (LOCAL, GOOGLE, BOTH) y dos roles globales (USER, ADMIN).
 * Los usuarios de Google pueden añadir contraseña después; en ese caso el proveedor pasa a BOTH.
 */
@Entity
@Table(name = "users")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class User {

    // ── Providers de autenticación ─────────────────────────────────────────
    public enum AuthProvider {
        LOCAL,   // registro clásico usuario/contraseña
        GOOGLE,  // solo Google OAuth
        BOTH     // empezó con Google, luego añadió contraseña (o viceversa)
    }

    // ── Roles globales de la aplicación ────────────────────────────────────
    public enum UserRole {
        USER,   // usuario normal
        ADMIN   // puede gestionar salas, géneros y usuarios
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Username único — se puede cambiar pero debe seguir siendo único
    @Column(nullable = false, unique = true, length = 50)
    private String username;

    @Column(nullable = false, unique = true, length = 100)
    private String email;

    // Nullable: los usuarios de Google no tienen contraseña hasta que la añadan
    @Column(nullable = true)
    private String password;

    // Nombre visible (puede tener espacios, no tiene que ser único)
    @Column(name = "display_name", length = 80)
    private String displayName;

    // URL de la foto de perfil (Cloudinary o Google)
    @Column(name = "avatar_url", length = 500)
    private String avatarUrl;

    // Bio / descripción (max 150 chars)
    @Column(name = "bio", length = 150)
    private String bio;

    // Método de autenticación — LOCAL por defecto para usuarios existentes
    @Enumerated(EnumType.STRING)
    @Column(name = "auth_provider", nullable = false, length = 10)
    private AuthProvider authProvider = AuthProvider.LOCAL;

    // ID único de Google — solo para cuentas con Google OAuth
    @Column(name = "google_id", unique = true, length = 100)
    private String googleId;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    // Si es true, el usuario no aparece en búsquedas ni puede recibir solicitudes de amistad
    @Column(name = "profile_hidden", nullable = false)
    private boolean profileHidden = false;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, columnDefinition = "VARCHAR(10) NOT NULL DEFAULT 'USER'")
    private UserRole role = UserRole.USER;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    public boolean hasPassword() {
        return this.password != null && !this.password.isBlank();
    }

    public boolean canLoginWithGoogle() {
        return this.authProvider == AuthProvider.GOOGLE
            || this.authProvider == AuthProvider.BOTH;
    }

    public boolean canLoginWithPassword() {
        return (this.authProvider == AuthProvider.LOCAL
            || this.authProvider == AuthProvider.BOTH)
            && hasPassword();
    }
}