package com.example.viber.controller;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.viber.service.YoutubeService;

/**
 * Proxy hacia la YouTube Data API v3.
 * Expone búsqueda de vídeos musicales e importación de playlists públicas.
 * La clave API reside en el backend para no exponerla en el cliente Flutter.
 */
@RestController
@RequestMapping("/api/youtube")
@CrossOrigin(origins = "*")
public class YoutubeController {

    @Autowired
    private YoutubeService youtubeService;

    // ── GET /api/youtube/search?q=duki ───────────────────────────────────────

    @GetMapping("/search")
    public ResponseEntity<?> search(@RequestParam String q) {
        if (q == null || q.trim().length() < 2) {
            throw new RuntimeException("La búsqueda debe tener al menos 2 caracteres");
        }
        List<Map<String, String>> results = youtubeService.search(q.trim());
        return ResponseEntity.ok(results);
    }

    // ── GET /api/youtube/playlist?url=<url_o_id>&max=50 ─────────────────────

    @GetMapping("/playlist")
    public ResponseEntity<?> playlist(
            @RequestParam String url,
            @RequestParam(defaultValue = "50") int max) {

        if (url == null || url.trim().isEmpty()) {
            throw new RuntimeException("La URL de la playlist no puede estar vacía");
        }

        String playlistId = YoutubeService.extractPlaylistId(url.trim());
        if (playlistId == null || playlistId.isEmpty()) {
            throw new RuntimeException(
                "No se pudo extraer el ID de la playlist. " +
                "Asegúrate de que la URL incluye el parámetro 'list='.");
        }

        List<Map<String, String>> items = youtubeService.getPlaylistItems(playlistId, max);
        if (items.isEmpty()) {
            throw new RuntimeException("La playlist no contiene vídeos públicos o no existe");
        }

        return ResponseEntity.ok(items);
    }
}
