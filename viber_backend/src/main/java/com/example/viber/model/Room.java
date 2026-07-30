package com.example.viber.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Sala de música colaborativa en tiempo real.
 * Puede ser PUBLIC (visible en el listado) o PRIVATE (acceso por código de 6 caracteres).
 * El campo {@code flagged} lo pone el admin cuando hay una incidencia; la sala deja de
 * aparecer públicamente aunque siga técnicamente activa.
 */
@Entity
@Table(name = "rooms")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Room {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(length = 255)
    private String description;

    // Géneros separados por coma: "Pop,Rock,Electronic"
    @Column(name = "genre", length = 200)
    private String genres;

    private Integer maxParticipants;

    // PUBLIC o PRIVATE
    @Column(nullable = false, length = 10)
    private String privacy = "PUBLIC";

    // Solo para salas privadas
    @Column(length = 10)
    private String accessCode;

    // Relación con el usuario que creó la sala (el Host)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "host_id", nullable = false)
    private User host;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    // Si la sala está activa o fue cerrada
    @Column(nullable = false)
    private boolean active = true;

    // Marcada por admin por incidencia — nunca aparece en listados públicos
    @Column(nullable = false, columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE")
    private boolean flagged = false;

    // Sala permanente: el auto-DJ rellena la cola con canciones afines a lo ya
    // reproducido cuando se queda corta (ver AutoDjService).
    @Column(name = "auto_dj", nullable = false, columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE")
    private boolean autoDj = false;

    // Motivo de la incidencia escrito por el admin (opcional, solo para uso interno)
    @Column(name = "flag_reason", length = 500)
    private String flagReason;

    // ── Personalización de la sala ───────────────────────────────────────────

    // URL de la imagen de portada (Cloudinary). Null = sin portada.
    @Column(name = "cover_image_url", length = 500)
    private String coverImageUrl;

    // Color de acento en formato hex "#RRGGBB". Null = color por defecto de la app.
    @Column(name = "accent_color", length = 9)
    private String accentColor;

    // Mensaje que se muestra a quien entra a la sala por primera vez. Null = sin mensaje.
    @Column(name = "welcome_message", length = 500)
    private String welcomeMessage;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}