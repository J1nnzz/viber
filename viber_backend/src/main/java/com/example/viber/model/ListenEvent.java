package com.example.viber.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Un evento "esta canción sonó para este usuario en esta sala en este instante".
 *
 * A diferencia de {@link ArtistPlayCount} (contador acumulado sin tiempo), aquí
 * guardamos el {@code playedAt} de cada reproducción: es lo que permite ponderar
 * por RECENCIA (time-decay) y que el rock de las últimas semanas pese más que el
 * hip-hop de hace un año. El género no se guarda aquí — se resuelve al calcular el
 * perfil cruzando {@code videoId} con {@link TrackMetadata} (que se enriquece async).
 *
 * Sirve para dos perfiles distintos a partir de la misma tabla:
 *  - filtrando por {@code user}    → gusto del usuario (recomendación de salas)
 *  - filtrando por {@code roomId}  → huella de la sala (recomendación + auto-DJ)
 *
 * Índice por (user_id, played_at) y (room_id, played_at) para las consultas por ventana.
 */
@Entity
@Table(
    name = "listen_events",
    indexes = {
        @Index(name = "idx_listen_user_time", columnList = "user_id, played_at"),
        @Index(name = "idx_listen_room_time", columnList = "room_id, played_at")
    }
)
@Data
@NoArgsConstructor
public class ListenEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "room_id")
    private Long roomId;

    @Column(name = "video_id", nullable = false, length = 50)
    private String videoId;

    /** Canal/artista tal cual se conocía al reproducir (pista hasta que se enriquece). */
    @Column(length = 150)
    private String artist;

    @Column(name = "played_at", updatable = false)
    private LocalDateTime playedAt;

    @PrePersist
    protected void onCreate() {
        this.playedAt = LocalDateTime.now();
    }
}
