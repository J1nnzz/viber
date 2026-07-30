package com.example.viber.service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class YoutubeService {

    @Value("${youtube.api.key}")
    private String apiKey;

    private final RestTemplate restTemplate = new RestTemplate();

    // ── Búsqueda de vídeos ────────────────────────────────────────────────────

    public List<Map<String, String>> search(String query) {
        try {
            String encoded = URLEncoder.encode(query, StandardCharsets.UTF_8);
            String url = String.format(
                "https://www.googleapis.com/youtube/v3/search" +
                "?part=snippet&type=video&videoCategoryId=10" +
                "&videoEmbeddable=true&maxResults=10&q=%s&key=%s",
                encoded, apiKey
            );

            Map<String, Object> response = restTemplate.getForObject(url, Map.class);

            List<Map<String, String>> results = new ArrayList<>();
            if (response == null || !response.containsKey("items")) return results;

            List<Map<String, Object>> items =
                (List<Map<String, Object>>) response.get("items");

            for (Map<String, Object> item : items) {
                Map<String, Object> idObj      = (Map<String, Object>) item.get("id");
                Map<String, Object> snippet    = (Map<String, Object>) item.get("snippet");
                Map<String, Object> thumbnails = (Map<String, Object>) snippet.get("thumbnails");
                Map<String, Object> mediumThumb = (Map<String, Object>) thumbnails.get("medium");

                String videoId = (String) idObj.get("videoId");
                String title   = (String) snippet.get("title");
                String thumb   = (String) mediumThumb.get("url");
                String channel = (String) snippet.get("channelTitle");

                if (videoId != null) {
                    results.add(Map.of(
                        "videoId",   videoId,
                        "title",     title,
                        "thumbnail", thumb,
                        "channel",   channel
                    ));
                }
            }

            return results;

        } catch (Exception e) {
            throw new RuntimeException("Error al buscar en YouTube: " + e.getMessage());
        }
    }

    // ── Importar playlist ─────────────────────────────────────────────────────

    /**
     * Devuelve hasta {@code maxItems} vídeos de una playlist pública de YouTube.
     * Coste API: 1 llamada playlistItems.list = 1 crédito (no 100 como search).
     *
     * @param playlistId  ID de la playlist (ej. "PLrEnWoR732-BHrPp_Pm8_VleD68f9s14-")
     * @param maxItems    Máximo de canciones a importar (1-50, por defecto 50)
     */
    public List<Map<String, String>> getPlaylistItems(String playlistId, int maxItems) {
        try {
            int limit = Math.min(Math.max(maxItems, 1), 50);

            String url = String.format(
                "https://www.googleapis.com/youtube/v3/playlistItems" +
                "?part=snippet&maxResults=%d&playlistId=%s&key=%s",
                limit, playlistId, apiKey
            );

            Map<String, Object> response = restTemplate.getForObject(url, Map.class);

            List<Map<String, String>> results = new ArrayList<>();
            if (response == null || !response.containsKey("items")) return results;

            List<Map<String, Object>> items =
                (List<Map<String, Object>>) response.get("items");

            for (Map<String, Object> item : items) {
                Map<String, Object> snippet    = (Map<String, Object>) item.get("snippet");
                Map<String, Object> resourceId = (Map<String, Object>) snippet.get("resourceId");
                Map<String, Object> thumbnails = (Map<String, Object>) snippet.get("thumbnails");

                String videoId = (String) resourceId.get("videoId");
                String title   = (String) snippet.get("title");

                // Vídeos eliminados/privados aparecen con título "Deleted video"
                if (videoId == null || "Deleted video".equals(title) || "Private video".equals(title)) {
                    continue;
                }

                // Thumbnail: preferimos medium, fallback a default
                String thumb = "";
                if (thumbnails != null) {
                    Map<String, Object> medium = (Map<String, Object>) thumbnails.get("medium");
                    Map<String, Object> def    = (Map<String, Object>) thumbnails.get("default");
                    if (medium != null)  thumb = (String) medium.get("url");
                    else if (def != null) thumb = (String) def.get("url");
                }

                String channel = (String) snippet.get("videoOwnerChannelTitle");
                if (channel == null) channel = "";

                results.add(Map.of(
                    "videoId",   videoId,
                    "title",     title,
                    "thumbnail", thumb,
                    "channel",   channel
                ));
            }

            fillMissingChannels(results);

            return results;

        } catch (Exception e) {
            throw new RuntimeException("Error al importar la playlist: " + e.getMessage());
        }
    }

    /**
     * playlistItems.list no siempre rellena "videoOwnerChannelTitle" (p.ej. canales
     * "- Topic" o vídeos cuyo canal cambió). Para esos vídeos consultamos videos.list,
     * que sí expone "channelTitle" de forma fiable (igual que search()). Una sola
     * llamada por playlist, hasta 50 IDs, coste 1 unidad de cuota.
     */
    private void fillMissingChannels(List<Map<String, String>> results) {
        List<String> missingIds = new ArrayList<>();
        for (Map<String, String> r : results) {
            String channel = r.get("channel");
            if ((channel == null || channel.isBlank()) && !missingIds.contains(r.get("videoId"))) {
                missingIds.add(r.get("videoId"));
            }
        }
        if (missingIds.isEmpty()) return;

        try {
            String url = String.format(
                "https://www.googleapis.com/youtube/v3/videos" +
                "?part=snippet&id=%s&key=%s",
                String.join(",", missingIds), apiKey
            );

            Map<String, Object> response = restTemplate.getForObject(url, Map.class);
            if (response == null || !response.containsKey("items")) return;

            List<Map<String, Object>> items = (List<Map<String, Object>>) response.get("items");
            Map<String, String> channelByVideoId = new HashMap<>();
            for (Map<String, Object> item : items) {
                String id = (String) item.get("id");
                Map<String, Object> snippet = (Map<String, Object>) item.get("snippet");
                if (id == null || snippet == null) continue;
                String channelTitle = (String) snippet.get("channelTitle");
                if (channelTitle != null) channelByVideoId.put(id, channelTitle);
            }
            if (channelByVideoId.isEmpty()) return;

            for (int i = 0; i < results.size(); i++) {
                Map<String, String> r = results.get(i);
                String channel = r.get("channel");
                String fallback = channelByVideoId.get(r.get("videoId"));
                if ((channel == null || channel.isBlank()) && fallback != null) {
                    Map<String, String> updated = new HashMap<>(r);
                    updated.put("channel", fallback);
                    results.set(i, updated);
                }
            }
        } catch (Exception e) {
            // Si falla el fallback, dejamos los canales tal cual (mejor parcial que romper la importación)
        }
    }

    // ── Utilidad: extraer playlistId de una URL de YouTube ────────────────────

    /**
     * Acepta URLs del tipo:
     *   https://www.youtube.com/playlist?list=PLxxx
     *   https://youtube.com/watch?v=xxx&list=PLxxx
     *   PLxxx  (ID directo)
     */
    public static String extractPlaylistId(String input) {
        if (input == null || input.isBlank()) return null;
        String trimmed = input.trim();

        // Si ya es un ID puro (empieza por PL, RD, UU, FL, etc.)
        if (!trimmed.contains("://")) return trimmed;

        Pattern pattern = Pattern.compile("[?&]list=([^&]+)");
        Matcher matcher = pattern.matcher(trimmed);
        return matcher.find() ? matcher.group(1) : null;
    }
}