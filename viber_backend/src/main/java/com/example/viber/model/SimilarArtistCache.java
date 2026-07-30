package com.example.viber.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Caché del grafo de artistas similares. El grafo musical es casi estático
 * (los parecidos a Drake no cambian de un día para otro), así que se consulta la
 * fuente externa (Deezer/Last.fm/LLM) una vez por artista y se guarda aquí: tras
 * el calentamiento el auto-DJ apenas toca la red, lo que permite escalar a público.
 *
 * Los similares se guardan como una sola cadena separada por '|' (los nombres de
 * artista pueden llevar comas). {@code source} registra de dónde salió el dato.
 */
@Entity
@Table(name = "similar_artist_cache")
@Data
@NoArgsConstructor
public class SimilarArtistCache {

    /** Nombre del artista semilla normalizado (minúsculas, sin acentos) — clave. */
    @Id
    @Column(name = "seed_norm", length = 160)
    private String seedNorm;

    @Column(name = "seed_name", length = 160)
    private String seedName;

    @Column(name = "similar_csv", columnDefinition = "TEXT")
    private String similarCsv;

    /** DEEZER | LASTFM | LLM | NONE */
    @Column(length = 10)
    private String source;

    @Column(name = "fetched_at")
    private LocalDateTime fetchedAt;
}
