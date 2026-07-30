package com.example.viber.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
 * Tally de reproducciones por artista/canal de YouTube para cada usuario.
 * El par (user, artistName) es único: playCount se incrementa cada vez que una
 * canción de ese artista pasa a sonar mientras el usuario está online en la sala.
 */
@Entity
@Table(
    name = "artist_play_counts",
    uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "artist_name"})
)
@Data
@NoArgsConstructor
public class ArtistPlayCount {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "artist_name", nullable = false, length = 150)
    private String artistName;

    @Column(name = "play_count", nullable = false)
    private int playCount = 0;
}
