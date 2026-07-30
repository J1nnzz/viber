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
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Un intento dentro de una partida del quiz.
 * guessedSong = null representa un "saltar" (modo audio: gasta intento
 * para desbloquear más segundos sin arriesgar canción).
 * Las comparaciones no se persisten: se recalculan al servir el estado.
 */
@Entity
@Table(name = "quiz_guesses")
@Data
@NoArgsConstructor
public class QuizGuess {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "game_id", nullable = false)
    private QuizGame game;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "guessed_song_id")
    private QuizSong guessedSong;

    @Column(name = "guess_order", nullable = false)
    private int guessOrder;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
