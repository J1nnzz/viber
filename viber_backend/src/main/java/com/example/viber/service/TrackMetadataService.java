package com.example.viber.service;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.viber.model.TrackMetadata;
import com.example.viber.repository.TrackMetadataRepository;
import com.example.viber.service.DeezerService.DeezerTrack;

/**
 * Cache y enriquecimiento de metadatos por canción (Pieza 1 del sistema de
 * recomendación). La primera vez que un videoId aparece se consulta Deezer una
 * sola vez y se guarda; a partir de ahí cualquier perfil lo lee de la BD sin
 * tocar la red.
 *
 * El enriquecimiento es {@link Async}: nunca debe frenar la reproducción ni el
 * broadcast de la sala. Si Deezer no acierta, se guarda un registro YOUTUBE con
 * el canal como artista aproximado; si falla del todo, igual — lo importante es
 * marcar el videoId como "ya intentado" para no reconsultar en cada play.
 */
@Service
public class TrackMetadataService {

    @Autowired private DeezerService deezer;
    @Autowired private TrackMetadataRepository repo;

    // ── Lectura en lote (construcción de perfiles) ─────────────────────────────

    /** videoId → metadatos, solo de los que ya están cacheados (sin enriquecer). */
    @Transactional(readOnly = true)
    public Map<String, TrackMetadata> findByVideoIds(Collection<String> videoIds) {
        if (videoIds == null || videoIds.isEmpty()) return Map.of();
        List<String> ids = videoIds.stream().distinct().toList();
        Map<String, TrackMetadata> result = new HashMap<>();
        for (TrackMetadata tm : repo.findAllById(ids)) {
            result.put(tm.getVideoId(), tm);
        }
        return result;
    }

    // ── Enriquecimiento asíncrono ──────────────────────────────────────────────

    /**
     * Enriquece un videoId si aún no se había intentado. Pensado para llamarse
     * desde el hilo de la sala sin bloquear (corre en el pool de @Async).
     */
    @Async
    @Transactional
    public void enrichAsync(String videoId, String title, String channel) {
        if (videoId == null || videoId.isBlank()) return;
        if (repo.existsById(videoId)) return; // ya resuelto (con o sin match): no reintentar

        TrackMetadata tm = new TrackMetadata();
        tm.setVideoId(videoId);
        tm.setTitle(title);
        tm.setFetchedAt(LocalDateTime.now());

        try {
            Optional<DeezerTrack> match = deezer.match(title, channel);
            if (match.isPresent()) {
                DeezerTrack t = match.get();
                tm.setArtist(t.getArtistName());
                tm.setAlbum(t.getAlbumTitle());
                tm.setGenre(t.getGenre());
                tm.setReleaseYear(t.getReleaseYear());
                tm.setDurationSec(t.getDurationSec());
                tm.setSource("DEEZER");
            } else {
                tm.setArtist(emptyToNull(DeezerService.cleanChannelName(channel)));
                tm.setSource("YOUTUBE");
            }
        } catch (Exception e) {
            // Deezer caído/timeout: dejamos lo que sepamos por YouTube y seguimos
            tm.setArtist(emptyToNull(DeezerService.cleanChannelName(channel)));
            tm.setSource("YOUTUBE");
        }

        try {
            repo.save(tm);
        } catch (Exception ignore) {
            // Carrera: otro hilo guardó el mismo videoId primero. No pasa nada.
        }
    }

    private static String emptyToNull(String s) {
        return (s == null || s.isBlank()) ? null : s;
    }
}
