package com.example.viber.service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import com.example.viber.model.SimilarArtistCache;
import com.example.viber.repository.SimilarArtistCacheRepository;

/**
 * "¿Qué se parece a esto?" — la única parte realmente difícil del auto-DJ y de la
 * recomendación en frío (Pieza 5). Resuelve artistas similares con una cascada de
 * fuentes, de la más fiable/barata a la de último recurso, y cachea el resultado
 * en BD porque el grafo musical es casi estático:
 *
 *   1. Deezer  /artist/{id}/related  → sin API key, grafo curado. Columna vertebral.
 *   2. Last.fm artist.getSimilar     → opcional (lastfm.api.key); buen tagging.
 *   3. Groq LLM                       → fallback de cold-start (reusa groq.api.key
 *                                       de los emojis); offline, no en caliente.
 *
 * Si ninguna da resultado se cachea NONE para no machacar las APIs en cada intento.
 */
@Service
public class SimilarArtistService {

    private static final String LASTFM_API = "https://ws.audioscrobbler.com/2.0/";
    private static final String GROQ_API   = "https://api.groq.com/openai/v1/chat/completions";

    @Autowired private DeezerService deezer;
    @Autowired private SimilarArtistCacheRepository cacheRepo;

    @Value("${lastfm.api.key:}")
    private String lastfmKey;

    @Value("${groq.api.key:}")
    private String groqKey;

    @Value("${groq.model:llama-3.3-70b-versatile}")
    private String groqModel;

    private final RestTemplate restTemplate = buildRestTemplate();

    private static RestTemplate buildRestTemplate() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5_000);
        factory.setReadTimeout(15_000);
        return new RestTemplate(factory);
    }

    // ── API pública ─────────────────────────────────────────────────────────────

    /** Artistas similares a {@code artistName}, cacheados. Lista vacía si no se sabe. */
    @Transactional
    public List<String> similarArtists(String artistName) {
        if (artistName == null || artistName.isBlank()) return List.of();
        String norm = normalize(artistName);

        SimilarArtistCache cached = cacheRepo.findById(norm).orElse(null);
        if (cached != null) {
            return split(cached.getSimilarCsv());
        }

        Fetched fetched = fetchSimilar(artistName);

        SimilarArtistCache entry = new SimilarArtistCache();
        entry.setSeedNorm(norm);
        entry.setSeedName(artistName);
        entry.setSimilarCsv(String.join("|", fetched.names()));
        entry.setSource(fetched.source());
        entry.setFetchedAt(LocalDateTime.now());
        try {
            cacheRepo.save(entry);
        } catch (Exception ignore) {
            // Carrera: otro hilo cacheó el mismo artista. Da igual.
        }

        return fetched.names();
    }

    /**
     * Títulos de canciones reales del artista (Deezer top tracks). Convierte un
     * nombre de artista en algo concreto que buscar en YouTube.
     */
    public List<String> topTracksForArtist(String artistName, int n) {
        return deezer.searchArtistId(artistName)
            .map(id -> deezer.topTrackTitles(id, n))
            .orElse(List.of());
    }

    // ── Cascada de fuentes ────────────────────────────────────────────────────

    private Fetched fetchSimilar(String artistName) {
        // 1) Deezer (sin key)
        List<String> deezerRelated = deezer.searchArtistId(artistName)
            .map(deezer::relatedArtists)
            .orElse(List.of());
        if (!deezerRelated.isEmpty()) return new Fetched(deezerRelated, "DEEZER");

        // 2) Last.fm (opcional)
        if (lastfmConfigured()) {
            List<String> lastfm = lastfmSimilar(artistName);
            if (!lastfm.isEmpty()) return new Fetched(lastfm, "LASTFM");
        }

        // 3) Groq LLM (cold-start, opcional)
        if (groqConfigured()) {
            List<String> llm = llmSimilar(artistName);
            if (!llm.isEmpty()) return new Fetched(llm, "LLM");
        }

        return new Fetched(List.of(), "NONE");
    }

    private boolean lastfmConfigured() { return lastfmKey != null && !lastfmKey.isBlank(); }
    private boolean groqConfigured()   { return groqKey != null && !groqKey.isBlank(); }

    // ── Last.fm ─────────────────────────────────────────────────────────────────

    private List<String> lastfmSimilar(String artistName) {
        try {
            String url = LASTFM_API + "?method=artist.getsimilar&limit=20&autocorrect=1"
                + "&artist=" + URLEncoder.encode(artistName, StandardCharsets.UTF_8)
                + "&api_key=" + lastfmKey.trim()
                + "&format=json";
            String response = restTemplate.getForObject(java.net.URI.create(url), String.class);
            if (response == null) return List.of();

            JSONObject root = new JSONObject(response);
            JSONObject similar = root.optJSONObject("similarartists");
            if (similar == null) return List.of();
            JSONArray arr = similar.optJSONArray("artist");
            if (arr == null) return List.of();

            List<String> names = new ArrayList<>();
            for (int i = 0; i < arr.length(); i++) {
                JSONObject a = arr.optJSONObject(i);
                if (a == null) continue;
                String name = a.optString("name", null);
                if (name != null && !name.isBlank()) names.add(name);
            }
            return names;
        } catch (Exception e) {
            return List.of();
        }
    }

    // ── Groq LLM (mismo patrón REST que EmojiSuggestService) ──────────────────

    private List<String> llmSimilar(String artistName) {
        JSONObject body = new JSONObject()
            .put("model", groqModel)
            .put("temperature", 0.4)
            .put("max_tokens", 512)
            .put("response_format", new JSONObject().put("type", "json_object"))
            .put("messages", new JSONArray()
                .put(new JSONObject()
                    .put("role", "system")
                    .put("content", "Eres un experto en música. Respondes SIEMPRE con JSON válido."))
                .put(new JSONObject()
                    .put("role", "user")
                    .put("content", "Dame 15 artistas musicales reales y conocidos cuyo estilo se "
                        + "parezca al de \"" + artistName + "\". No incluyas a \"" + artistName
                        + "\". Responde EXCLUSIVAMENTE con JSON: {\"artists\": [\"Nombre 1\", \"Nombre 2\"]}")));

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(groqKey.trim());

        try {
            String response = restTemplate.postForObject(
                java.net.URI.create(GROQ_API),
                new HttpEntity<>(body.toString(), headers),
                String.class);
            String content = new JSONObject(response)
                .getJSONArray("choices").getJSONObject(0)
                .getJSONObject("message").getString("content");

            JSONArray arr = new JSONObject(content).optJSONArray("artists");
            if (arr == null) return List.of();
            List<String> names = new ArrayList<>();
            for (int i = 0; i < arr.length(); i++) {
                String name = arr.optString(i, null);
                if (name != null && !name.isBlank()) names.add(name.trim());
            }
            return names;
        } catch (Exception e) {
            return List.of();
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static String normalize(String s) {
        String n = Normalizer.normalize(s.toLowerCase(Locale.ROOT), Normalizer.Form.NFD)
            .replaceAll("\\p{M}", "")
            .trim();
        return n.length() > 160 ? n.substring(0, 160) : n;
    }

    private static List<String> split(String csv) {
        if (csv == null || csv.isBlank()) return List.of();
        List<String> names = new ArrayList<>();
        for (String s : csv.split("\\|")) {
            if (!s.isBlank()) names.add(s.trim());
        }
        return names;
    }

    /** Resultado de una búsqueda de similares: nombres + de qué fuente vinieron. */
    private record Fetched(List<String> names, String source) {}
}
