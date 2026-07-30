package com.example.viber.service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

/**
 * Cliente de lrclib.net — letras gratuitas, sin API key.
 * Se usa para el modo "letra" del quiz: al importar una canción (ya matcheada
 * en Deezer) se intenta guardar su letra en texto plano.
 *
 * Distingue dos casos que NO son lo mismo:
 *  - lrclib respondió y no tiene la letra → Optional.empty() (miss real).
 *  - lrclib no responde / error de red → {@link LrclibUnavailable}, para que
 *    quien llama NO marque la canción como "sin letra" y pueda reintentar.
 *
 * lrclib pide identificarse con User-Agent; respondemos con el nombre del
 * proyecto como indica su documentación.
 */
@Service
public class LrclibService {

    private static final String API = "https://lrclib.net/api";
    private static final String USER_AGENT = "Viber-Quiz/1.0 (proyecto educativo DAM)";

    /** lrclib caído o demasiado lento — reintentar más tarde, no marcar nada. */
    public static class LrclibUnavailable extends RuntimeException {
        public LrclibUnavailable(String message) { super(message); }
    }

    // Con timeouts: una petición colgada no puede bloquear un import entero
    private final RestTemplate restTemplate = buildRestTemplate();

    private static RestTemplate buildRestTemplate() {
        org.springframework.http.client.SimpleClientHttpRequestFactory factory =
            new org.springframework.http.client.SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5_000);
        factory.setReadTimeout(15_000);
        return new RestTemplate(factory);
    }

    /**
     * Busca la letra en texto plano de una canción.
     * 1º intento exacto (/get con artista+título+duración, tolerancia ±2 s);
     * 2º búsqueda difusa (/search) quedándonos con el primer resultado con letra.
     *
     * @throws LrclibUnavailable si lrclib no responde (no concluyente)
     */
    public Optional<String> fetchPlainLyrics(String artistName, String title, Integer durationSec) {
        if (artistName == null || title == null) return Optional.empty();

        // ── 1. Match exacto (404 = miss, seguimos con la búsqueda) ────────────
        StringBuilder getUrl = new StringBuilder(API + "/get?artist_name=" + encode(artistName)
            + "&track_name=" + encode(title));
        if (durationSec != null) getUrl.append("&duration=").append(durationSec);

        Optional<String> exact = extractLyrics(getJson(getUrl.toString()));
        if (exact.isPresent()) return exact;

        // ── 2. Búsqueda difusa ────────────────────────────────────────────────
        List<?> results = getJsonList(
            API + "/search?artist_name=" + encode(artistName) + "&track_name=" + encode(title));
        for (Object item : results) {
            if (item instanceof Map<?, ?> m) {
                @SuppressWarnings("unchecked")
                Optional<String> lyrics = extractLyrics((Map<String, Object>) m);
                if (lyrics.isPresent()) return lyrics;
            }
        }
        return Optional.empty();    // lrclib respondió: de verdad no la tiene
    }

    private Optional<String> extractLyrics(Map<String, Object> body) {
        if (body == null) return Optional.empty();
        if (Boolean.TRUE.equals(body.get("instrumental"))) return Optional.empty();
        String plain = body.get("plainLyrics") instanceof String s ? s.trim() : "";
        return plain.isEmpty() ? Optional.empty() : Optional.of(plain);
    }

    // ── HTTP con User-Agent ───────────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    private Map<String, Object> getJson(String url) {
        try {
            return restTemplate.exchange(
                java.net.URI.create(url), HttpMethod.GET, userAgentEntity(), Map.class).getBody();
        } catch (HttpClientErrorException.NotFound e) {
            return null;    // 404: lrclib respondió y no existe — miss real
        } catch (Exception e) {
            throw new LrclibUnavailable("lrclib no responde: " + e.getMessage());
        }
    }

    private List<?> getJsonList(String url) {
        try {
            List<?> list = restTemplate.exchange(
                java.net.URI.create(url), HttpMethod.GET, userAgentEntity(), List.class).getBody();
            return list != null ? list : List.of();
        } catch (HttpClientErrorException.NotFound e) {
            return List.of();
        } catch (Exception e) {
            throw new LrclibUnavailable("lrclib no responde: " + e.getMessage());
        }
    }

    private HttpEntity<Void> userAgentEntity() {
        HttpHeaders headers = new HttpHeaders();
        headers.set(HttpHeaders.USER_AGENT, USER_AGENT);
        return new HttpEntity<>(headers);
    }

    private static String encode(String s) {
        return URLEncoder.encode(s, StandardCharsets.UTF_8);
    }
}
