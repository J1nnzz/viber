package com.example.viber.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Metadatos estructurados de una canción de YouTube, cacheados por videoId.
 *
 * YouTube solo da título/canal/miniatura; aquí guardamos lo que falta para poder
 * recomendar y rellenar salas: artista real, álbum, género, año y duración.
 * El enriquecimiento lo hace {@link com.example.viber.service.TrackMetadataService}
 * de forma asíncrona vía {@link com.example.viber.service.DeezerService} la primera
 * vez que una canción suena en cualquier sala; a partir de ahí es coste cero.
 *
 * El campo {@code source} distingue de dónde salió el dato:
 *  - DEEZER  → match exacto en Deezer (artista/álbum/género fiables)
 *  - YOUTUBE → solo se conoce el canal (fallback cuando Deezer no acierta)
 *  - NONE    → consultado y sin resultado (evita reintentar en cada reproducción)
 */
@Entity
@Table(name = "track_metadata")
@Data
@NoArgsConstructor
public class TrackMetadata {

    /** videoId de YouTube — la misma clave que usa el resto de la app. */
    @Id
    @Column(name = "video_id", length = 50)
    private String videoId;

    @Column(length = 255)
    private String title;

    @Column(length = 150)
    private String artist;

    @Column(length = 255)
    private String album;

    @Column(length = 80)
    private String genre;

    @Column(name = "release_year")
    private Integer releaseYear;

    @Column(name = "duration_sec")
    private Integer durationSec;

    /** DEEZER | YOUTUBE | NONE — ver javadoc de la clase. */
    @Column(length = 10)
    private String source;

    @Column(name = "fetched_at")
    private LocalDateTime fetchedAt;

    /** true si el enriquecimiento ya se intentó (con o sin éxito): no reintentar. */
    public boolean isResolved() {
        return source != null;
    }
}
