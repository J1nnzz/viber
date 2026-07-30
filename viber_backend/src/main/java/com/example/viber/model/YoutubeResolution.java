package com.example.viber.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Caché de "consulta de texto → vídeo de YouTube" para el auto-DJ.
 *
 * search.list de YouTube cuesta 100 unidades de cuota (de 10.000/día) y la key es
 * la MISMA que usan el buscador y el import del quiz: si el auto-DJ buscara en cada
 * relleno agotaría la cuota y rompería esas features. Como muchas salas comparten
 * artistas populares, cacheamos el videoId de cada consulta y tras el calentamiento
 * casi todos los rellenos son aciertos de caché (cero cuota).
 *
 * {@code videoId} nulo = "ya se buscó y no había resultado" (no reintentar).
 */
@Entity
@Table(name = "youtube_resolution")
@Data
@NoArgsConstructor
public class YoutubeResolution {

    /** Consulta normalizada (minúsculas, sin acentos, espacios colapsados). */
    @Id
    @Column(name = "query_key", length = 200)
    private String queryKey;

    @Column(name = "video_id", length = 50)
    private String videoId;

    @Column(length = 255)
    private String title;

    @Column(length = 500)
    private String thumbnail;

    @Column(length = 150)
    private String channel;

    @Column(name = "resolved_at")
    private LocalDateTime resolvedAt;
}
