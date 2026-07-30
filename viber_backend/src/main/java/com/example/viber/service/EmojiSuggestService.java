package com.example.viber.service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import com.example.viber.model.QuizSong;

/**
 * Genera los emojis del modo emoji del quiz con la API de Groq (gratis, sin
 * tarjeta). Groq es compatible con la API de OpenAI, así que basta una llamada
 * REST a /chat/completions con response_format=json_object — no hace falta SDK.
 *
 * Manda las canciones en LOTES de hasta {@link #BATCH_SIZE} en una sola llamada
 * y valida cada sugerencia antes de aceptarla (solo emojis, entre 2 y 5). Las
 * sugerencias son un borrador: el admin puede retocarlas al editar la canción.
 *
 * La key es opcional (groq.api.key): sin ella, {@link #isConfigured()} devuelve
 * false y el endpoint explica cómo conseguirla.
 */
@Service
public class EmojiSuggestService {

    public static final int BATCH_SIZE = 15;

    private static final String API_URL = "https://api.groq.com/openai/v1/chat/completions";

    @Value("${groq.api.key:}")
    private String apiKey;

    @Value("${groq.model:llama-3.3-70b-versatile}")
    private String model;

    // Con timeouts: una petición colgada no puede bloquear el lote entero
    private final RestTemplate restTemplate = buildRestTemplate();

    private static RestTemplate buildRestTemplate() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5_000);
        factory.setReadTimeout(30_000);
        return new RestTemplate(factory);
    }

    public boolean isConfigured() {
        return apiKey != null && !apiKey.isBlank();
    }

    // ── Generación ────────────────────────────────────────────────────────────

    /**
     * Una llamada a Groq para todo el lote. Devuelve songId → emojis ya
     * validados; las canciones sin sugerencia válida no aparecen en el mapa.
     *
     * @throws RuntimeException con mensaje amigable si la API falla
     */
    public Map<Long, String> suggestForBatch(List<QuizSong> songs) {
        if (songs.isEmpty()) return Map.of();

        JSONObject body = new JSONObject()
            .put("model", model)
            .put("temperature", 0.7)
            .put("max_tokens", 2048)
            .put("response_format", new JSONObject().put("type", "json_object"))
            .put("messages", new JSONArray()
                .put(new JSONObject()
                    .put("role", "system")
                    .put("content", "Eres un generador de emojis para un juego de adivinar "
                        + "canciones. Respondes SIEMPRE con JSON válido y solo emojis."))
                .put(new JSONObject()
                    .put("role", "user")
                    .put("content", buildPrompt(songs))));

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(apiKey.trim());

        String content;
        try {
            String response = restTemplate.postForObject(
                java.net.URI.create(API_URL),
                new HttpEntity<>(body.toString(), headers),
                String.class);
            content = new JSONObject(response)
                .getJSONArray("choices").getJSONObject(0)
                .getJSONObject("message").getString("content");
        } catch (HttpClientErrorException.Unauthorized e) {
            throw new RuntimeException("La API key de Groq no es válida (revisa groq.api.key)");
        } catch (HttpClientErrorException.TooManyRequests e) {
            throw new RuntimeException(
                "Has alcanzado el límite del tier gratis de Groq; espera un minuto y reintenta");
        } catch (Exception e) {
            throw new RuntimeException("Error llamando a la API de Groq: " + e.getMessage());
        }

        return parseAndValidate(content);
    }

    /** Construye el prompt con el contexto de cada canción y la forma del JSON pedido. */
    private String buildPrompt(List<QuizSong> songs) {
        StringBuilder list = new StringBuilder();
        for (QuizSong s : songs) {
            list.append("- id=").append(s.getId())
                .append(" | \"").append(s.getTitle())
                .append("\" de ").append(s.getArtistName());
            if (s.getGenre() != null) list.append(" | género: ").append(s.getGenre());
            if (s.getReleaseYear() != null) list.append(" | año: ").append(s.getReleaseYear());
            String excerpt = lyricsExcerpt(s);
            if (excerpt != null) list.append("\n  letra: ").append(excerpt);
            list.append('\n');
        }

        return """
            Estas canciones son retos de un juego de adivinar canciones con emojis \
            (tipo LoLdle): el jugador ve los emojis uno a uno e intenta adivinar el título.

            Para CADA canción devuelve de 3 a 5 emojis separados por espacios que \
            evoquen su título (juegos de palabras bienvenidos), tema o ambiente.
            Reglas:
            - SOLO emojis: nada de letras, números ni signos de puntuación.
            - No deletrees el nombre del artista ni uses banderas de su país.
            - Ordena los emojis del más críptico al más revelador.

            Responde EXCLUSIVAMENTE con JSON de esta forma exacta:
            {"items": [{"songId": <id>, "emojis": "🎵 🔥 💃"}]}
            Usa exactamente los id que te doy, uno por canción.

            Canciones:
            %s""".formatted(list);
    }

    /** Parsea la respuesta JSON de Groq y se queda solo con sugerencias válidas. */
    private Map<Long, String> parseAndValidate(String content) {
        Map<Long, String> valid = new HashMap<>();
        try {
            JSONArray items = new JSONObject(content).optJSONArray("items");
            if (items == null) return valid;
            for (int i = 0; i < items.length(); i++) {
                JSONObject item = items.optJSONObject(i);
                if (item == null) continue;
                long songId = item.optLong("songId", -1);
                String clean = sanitize(item.optString("emojis", null));
                if (songId > 0 && clean != null) valid.put(songId, clean);
            }
        } catch (Exception e) {
            // Respuesta no parseable → lote sin sugerencias (no rompemos nada)
        }
        return valid;
    }

    /** Primeras ~4 líneas de la letra como contexto (si la hay). */
    private static String lyricsExcerpt(QuizSong s) {
        if (s.getLyrics() == null || s.getLyrics().isBlank()) return null;
        List<String> lines = s.getLyrics().lines()
            .filter(l -> !l.isBlank())
            .limit(4)
            .toList();
        return lines.isEmpty() ? null : String.join(" / ", lines);
    }

    // ── Validación ────────────────────────────────────────────────────────────

    /**
     * Acepta solo tokens sin letras ni dígitos (emojis y sus modificadores),
     * y entre 2 y 5 emojis. Devuelve null si no queda nada válido.
     */
    static String sanitize(String raw) {
        if (raw == null || raw.isBlank()) return null;

        List<String> kept = new ArrayList<>();
        for (String token : raw.trim().split("\\s+")) {
            if (token.isBlank() || token.length() > 16) continue;
            boolean hasAlnum = token.codePoints().anyMatch(Character::isLetterOrDigit);
            if (!hasAlnum) kept.add(token);
            if (kept.size() == 5) break;
        }
        return kept.size() >= 2 ? String.join(" ", kept) : null;
    }
}
