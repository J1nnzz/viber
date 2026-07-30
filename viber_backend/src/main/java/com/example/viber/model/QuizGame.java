package com.example.viber.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Partida de un usuario contra una canción secreta.
 *
 * Diaria:   vinculada a un {@link QuizDaily} — única por (usuario, daily).
 * Práctica: daily = null, practice = true — el usuario puede crear tantas como quiera
 *           (modo "infinito", útil además para la demo sin esperar al día siguiente).
 *
 * La canción secreta NUNCA viaja al cliente hasta que finished = true;
 * el backend solo devuelve las comparaciones de cada intento.
 */
@Entity
@Table(
    name = "quiz_games",
    uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "daily_id"})
)
@Data
@NoArgsConstructor
public class QuizGame {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private QuizMode mode;

    @Column(nullable = false)
    private boolean practice = false;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "daily_id")
    private QuizDaily daily;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "secret_song_id", nullable = false)
    private QuizSong secretSong;

    @Column(nullable = false)
    private boolean solved = false;

    /** true cuando la partida terminó: acertada, rendida o sin intentos (audio). */
    @Column(nullable = false)
    private boolean finished = false;

    /**
     * Puntos de ranking, congelados cuando la partida termina (null mientras se
     * juega; 0 en práctica, que no puntúa). Guardarlos en la propia partida hace
     * que el leaderboard sea una simple suma estable: cambiar la fórmula de
     * puntuación no reescribe las partidas ya jugadas.
     */
    @Column
    private Integer points;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
