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
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Registro persistente de una partida de quiz en vivo (competición tipo Kahoot).
 *
 * El estado en directo (ronda actual, puntuaciones, temporizadores) vive en
 * memoria en {@link com.example.viber.service.QuizMatchService}; esta entidad
 * solo guarda la cabecera y, al terminar, el ganador. Las puntuaciones finales
 * por jugador se guardan en {@link QuizMatchResult}.
 */
@Entity
@Table(name = "quiz_matches")
@Data
@NoArgsConstructor
public class QuizMatch {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Modo de pista de la partida (EMOJI, LYRICS, COVER, AUDIO)
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private QuizMode mode;

    // DM (duelo 1v1 desde un chat) | GROUP (todos contra todos en un grupo)
    @Column(nullable = false, length = 10)
    private String scope;

    // Solo si scope = GROUP
    @Column(name = "group_id")
    private Long groupId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "creator_id", nullable = false)
    private User creator;

    @Column(name = "total_rounds", nullable = false)
    private Integer totalRounds;

    @Column(name = "seconds_per_round", nullable = false)
    private Integer secondsPerRound;

    // LOBBY | RUNNING | FINISHED
    @Column(nullable = false, length = 10)
    private String status = "LOBBY";

    @Column(name = "winner_username", length = 50)
    private String winnerUsername;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "finished_at")
    private LocalDateTime finishedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
