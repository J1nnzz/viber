package com.example.viber.model;

import java.time.LocalDate;

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
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Canción secreta del día para un modo concreto.
 * Se crea de forma perezosa la primera vez que alguien abre el quiz ese día;
 * la elección es determinista (semilla = día epoch) para que una condición de
 * carrera entre dos usuarios a medianoche elija siempre la misma canción.
 */
@Entity
@Table(
    name = "quiz_dailies",
    uniqueConstraints = @UniqueConstraint(columnNames = {"quiz_date", "mode"})
)
@Data
@NoArgsConstructor
public class QuizDaily {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "quiz_date", nullable = false)
    private LocalDate date;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private QuizMode mode;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "song_id", nullable = false)
    private QuizSong song;
}
