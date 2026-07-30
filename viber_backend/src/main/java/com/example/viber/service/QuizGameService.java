package com.example.viber.service;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Random;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import com.example.viber.dto.QuizGameStateResponse;
import com.example.viber.dto.QuizGameStateResponse.FieldView;
import com.example.viber.dto.QuizGameStateResponse.GuessView;
import com.example.viber.dto.QuizGameStateResponse.Hints;
import com.example.viber.dto.QuizSongResponse;
import com.example.viber.exception.ForbiddenException;
import com.example.viber.exception.NotFoundException;
import com.example.viber.model.QuizDaily;
import com.example.viber.model.QuizGame;
import com.example.viber.model.QuizGuess;
import com.example.viber.model.QuizMode;
import com.example.viber.model.QuizSong;
import com.example.viber.model.User;
import com.example.viber.repository.QuizDailyRepository;
import com.example.viber.repository.QuizGameRepository;
import com.example.viber.repository.QuizGuessRepository;
import com.example.viber.repository.QuizSongRepository;

/**
 * Lógica del minijuego de adivinar canciones.
 *
 * Reglas:
 *  - CLASSIC: intentos ilimitados; cada intento compara artista, género, año,
 *    duración y explícito. Pistas extra: portada tras 5 fallos, inicial del
 *    título tras 8.
 *  - Modos de pista (AUDIO, LYRICS, COVER, EMOJI): 6 intentos (adivinar o
 *    saltar); cada uno agranda la pista — más segundos de preview, una línea
 *    más de letra (con el título censurado), portada con más resolución o un
 *    emoji más.
 *
 * La canción secreta nunca sale del backend hasta que la partida termina:
 * el cliente solo recibe comparaciones; el MP3 y la portada pixelada van por
 * proxy para no delatar la respuesta.
 */
@Service
public class QuizGameService {

    public static final List<Integer> SNIPPET_STEPS = List.of(1, 2, 4, 7, 12, 30);

    /** Intentos en los modos de pista (audio, letra, portada, emoji). */
    public static final int CLUE_MAX_ATTEMPTS = 6;

    /** Resolución (px de lado) de la portada pixelada por nº de intento. */
    public static final List<Integer> COVER_PIXEL_STEPS = List.of(6, 8, 12, 16, 24, 40);

    /** Fallos necesarios en clásico para desbloquear cada pista. */
    public static final int HINT_COVER_AT = 5;
    public static final int HINT_TITLE_AT = 8;

    /** Días sin repetir canción en el reto diario (si el pool lo permite). */
    private static final int NO_REPEAT_DAYS = 30;

    // ── Puntuación de ranking ───────────────────────────────────────────────────
    // Solo puntúa el RETO DIARIO (la práctica es infinita → no rankea). Una
    // partida diaria da: participación por presentarse (gane o no) + un bonus por
    // resolver que decae con cada fallo, con suelo. La misma curva sirve para el
    // clásico (intentos ilimitados) y los modos de pista (6 intentos): no depende
    // de un máximo, así que los puntos son comparables entre modos.
    public static final int POINTS_PARTICIPATION = 20;
    public static final int POINTS_SOLVE_BASE    = 200;
    public static final int POINTS_SOLVE_STEP    = 30;
    public static final int POINTS_SOLVE_FLOOR   = 50;

    // Bonus de constancia: +5 por cada día seguido resolviendo (tope +50). Se
    // concede UNA vez al día, en la primera diaria que resuelves ese día.
    public static final int STREAK_BONUS_STEP = 5;
    public static final int STREAK_BONUS_MAX  = 50;

    @Autowired private QuizSongRepository  quizSongRepository;
    @Autowired private QuizDailyRepository quizDailyRepository;
    @Autowired private QuizGameRepository  quizGameRepository;
    @Autowired private QuizGuessRepository quizGuessRepository;
    @Autowired private DeezerService       deezerService;

    // Para descargar preview/portada; con timeouts para no colgar peticiones
    private final RestTemplate restTemplate = buildRestTemplate();

    private static RestTemplate buildRestTemplate() {
        org.springframework.http.client.SimpleClientHttpRequestFactory factory =
            new org.springframework.http.client.SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5_000);
        factory.setReadTimeout(15_000);
        return new RestTemplate(factory);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Autocompletado
    // ══════════════════════════════════════════════════════════════════════════

    public List<QuizSongResponse> searchPool(String query, QuizMode mode) {
        String q = query.toLowerCase().trim();
        List<QuizSong> songs = (mode == QuizMode.CLASSIC)
            ? quizSongRepository.searchClassicEligible(q, PageRequest.of(0, 10))
            : quizSongRepository.searchActive(q, PageRequest.of(0, 10));
        return songs.stream().map(QuizSongResponse::forAutocomplete).toList();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Crear / recuperar partidas
    // ══════════════════════════════════════════════════════════════════════════

    /** Partida diaria del usuario (se crea si no existe, igual que el QuizDaily). */
    public QuizGameStateResponse dailyGame(User user, QuizMode mode) {
        QuizDaily daily = getOrCreateDaily(mode);

        QuizGame game = quizGameRepository.findByUserAndDaily(user, daily).orElseGet(() -> {
            QuizGame g = new QuizGame();
            g.setUser(user);
            g.setMode(mode);
            g.setDaily(daily);
            g.setSecretSong(daily.getSong());
            try {
                return quizGameRepository.save(g);
            } catch (Exception e) {
                // Doble click / carrera: ya existe la partida de este usuario
                return quizGameRepository.findByUserAndDaily(user, daily)
                    .orElseThrow(() -> new RuntimeException("No se pudo crear la partida"));
            }
        });

        return buildState(game);
    }

    /** Nueva partida de práctica con canción aleatoria (modo infinito). */
    public QuizGameStateResponse newPracticeGame(User user, QuizMode mode) {
        List<QuizSong> eligible = eligibleSongs(mode);
        if (eligible.isEmpty()) {
            throw new RuntimeException(
                "El pool del quiz aún no tiene canciones jugables para este modo");
        }

        // No usar las canciones de los retos diarios de HOY (de cualquier modo)
        // para no chafarlos jugando práctica (si hay más opciones)
        Set<Long> todaysDailySongs = quizDailyRepository.findByDate(LocalDate.now()).stream()
            .map(d -> d.getSong().getId())
            .collect(Collectors.toSet());
        List<QuizSong> candidates = eligible.stream()
            .filter(s -> !todaysDailySongs.contains(s.getId()))
            .toList();
        if (candidates.isEmpty()) candidates = eligible;

        QuizSong secret = candidates.get(new Random().nextInt(candidates.size()));

        QuizGame game = new QuizGame();
        game.setUser(user);
        game.setMode(mode);
        game.setPractice(true);
        game.setSecretSong(secret);
        quizGameRepository.save(game);

        return buildState(game);
    }

    /** Estado actual de una partida (para reabrirla sin tocar nada). */
    public QuizGameStateResponse gameState(User user, Long gameId) {
        return buildState(ownedGame(user, gameId));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Jugar
    // ══════════════════════════════════════════════════════════════════════════

    public QuizGameStateResponse guess(User user, Long gameId, Long songId) {
        QuizGame game = ownedGame(user, gameId);
        if (game.isFinished()) throw new RuntimeException("La partida ya está terminada");

        QuizSong song = quizSongRepository.findById(songId)
            .filter(QuizSong::isActive)
            .orElseThrow(() -> new NotFoundException("Esa canción no está en el pool del quiz"));

        if (game.getMode() == QuizMode.CLASSIC && !song.isClassicEligible()) {
            throw new RuntimeException("Esa canción no es válida para el modo clásico");
        }
        if (quizGuessRepository.existsByGameAndGuessedSongId(game, song.getId())) {
            throw new RuntimeException("Ya has probado esa canción en esta partida");
        }

        registerGuess(game, song);

        if (song.getId().equals(game.getSecretSong().getId())) {
            game.setSolved(true);
            markFinished(game);
        } else if (game.getMode().isClueMode()
                && quizGuessRepository.countByGame(game) >= CLUE_MAX_ATTEMPTS) {
            markFinished(game);
        }
        quizGameRepository.save(game);

        return buildState(game);
    }

    /** Saltar turno (modos de pista): gasta un intento para agrandar la pista. */
    public QuizGameStateResponse skip(User user, Long gameId) {
        QuizGame game = ownedGame(user, gameId);
        if (game.isFinished()) throw new RuntimeException("La partida ya está terminada");
        if (!game.getMode().isClueMode()) {
            throw new RuntimeException("En el modo clásico no se puede saltar");
        }

        registerGuess(game, null);

        if (quizGuessRepository.countByGame(game) >= CLUE_MAX_ATTEMPTS) {
            markFinished(game);
            quizGameRepository.save(game);
        }
        return buildState(game);
    }

    /** Rendirse: termina la partida y revela la respuesta. */
    public QuizGameStateResponse surrender(User user, Long gameId) {
        QuizGame game = ownedGame(user, gameId);
        if (game.isFinished()) throw new RuntimeException("La partida ya está terminada");
        markFinished(game);
        quizGameRepository.save(game);
        return buildState(game);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Puntuación de ranking (solo reto diario)
    // ══════════════════════════════════════════════════════════════════════════

    /** Marca la partida como terminada y congela sus puntos de ranking. */
    private void markFinished(QuizGame game) {
        game.setFinished(true);
        int attempts = quizGuessRepository.countByGame(game);
        game.setPoints(computePoints(game, attempts) + streakBonus(game));
    }

    /** Puntos base de una partida terminada (0 en práctica). attempts = intentos totales. */
    private int computePoints(QuizGame game, int attempts) {
        if (game.isPractice()) return 0;
        int points = POINTS_PARTICIPATION;
        if (game.isSolved()) {
            int wrong = Math.max(0, attempts - 1); // el último intento fue el acierto
            points += Math.max(POINTS_SOLVE_FLOOR,
                               POINTS_SOLVE_BASE - POINTS_SOLVE_STEP * wrong);
        }
        return points;
    }

    /**
     * Bonus de constancia. Solo si esta partida es la PRIMERA diaria que el
     * usuario resuelve hoy (las demás del mismo día no repiten bonus). El guess
     * acertado ya está guardado pero el game aún no, así que si ya existe OTRA
     * diaria resuelta hoy es que el bonus ya se concedió.
     */
    private int streakBonus(QuizGame game) {
        if (game.isPractice() || !game.isSolved()) return 0;
        LocalDate today = LocalDate.now();
        if (quizGameRepository.countSolvedDailyOn(game.getUser(), today) > 0) return 0;

        Set<LocalDate> solved = new java.util.HashSet<>(
            quizGameRepository.solvedDailyDates(game.getUser()));
        solved.add(today); // la de hoy aún no está persistida
        int streak = 0;
        for (LocalDate d = today; solved.contains(d); d = d.minusDays(1)) streak++;
        return Math.min(STREAK_BONUS_MAX, STREAK_BONUS_STEP * streak);
    }

    private void registerGuess(QuizGame game, QuizSong song) {
        QuizGuess guess = new QuizGuess();
        guess.setGame(game);
        guess.setGuessedSong(song);
        guess.setGuessOrder(quizGuessRepository.countByGame(game) + 1);
        quizGuessRepository.save(guess);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Audio por proxy
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Descarga el preview MP3 de 30 s de la canción secreta y lo devuelve como
     * bytes. Así el cliente nunca ve la URL de Deezer (contiene el ID del track
     * y delataría la respuesta en las DevTools).
     *
     * La URL guardada al importar caduca (Deezer las firma con expiración), así
     * que se pide una fresca a Deezer en cada partida.
     */
    public byte[] audioPreview(User user, Long gameId) {
        QuizGame game = ownedGame(user, gameId);
        if (game.getMode() != QuizMode.AUDIO) {
            throw new RuntimeException("Esta partida no es del modo audio");
        }
        QuizSong secret = game.getSecretSong();
        String url = deezerService.freshPreviewUrl(secret.getDeezerTrackId())
            .orElse(secret.getPreviewUrl());
        if (url == null || url.isBlank()) {
            throw new NotFoundException("La canción secreta no tiene preview disponible");
        }
        try {
            // URI.create evita que RestTemplate procese la URL como plantilla y
            // re-encodee la query: la firma (hdnea=...) debe viajar intacta al CDN
            byte[] bytes = restTemplate.getForObject(java.net.URI.create(url), byte[].class);
            if (bytes == null || bytes.length == 0) {
                throw new RuntimeException("Deezer devolvió un preview vacío");
            }
            return bytes;
        } catch (Exception e) {
            throw new RuntimeException("No se pudo descargar el preview: " + e.getMessage());
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Portada pixelada por proxy (modo portada)
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Sirve la carátula de la canción secreta reescalada a N×N píxeles según
     * los intentos gastados (6→8→12→16→24→40). El pixelado se hace en el
     * SERVIDOR: si se hiciera en el cliente, bastaría abrir la URL original
     * en las DevTools para ver la portada entera (con título y artista).
     */
    public byte[] coverImage(User user, Long gameId) {
        QuizGame game = ownedGame(user, gameId);
        if (game.getMode() != QuizMode.COVER) {
            throw new RuntimeException("Esta partida no es del modo portada");
        }
        String url = game.getSecretSong().getCoverUrl();
        if (url == null || url.isBlank()) {
            throw new NotFoundException("La canción secreta no tiene portada");
        }

        int attempts = quizGuessRepository.countByGame(game);
        int level = COVER_PIXEL_STEPS.get(
            Math.min(attempts, COVER_PIXEL_STEPS.size() - 1));

        try {
            byte[] original = restTemplate.getForObject(java.net.URI.create(url), byte[].class);
            if (original == null || original.length == 0) {
                throw new RuntimeException("No se pudo descargar la portada");
            }
            // Partida terminada → imagen original sin pixelar
            if (game.isFinished()) return original;
            return pixelate(original, level);
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException("No se pudo generar la portada: " + e.getMessage());
        }
    }

    /** Reduce la imagen a level×level px y la devuelve como PNG diminuto. */
    static byte[] pixelate(byte[] imageBytes, int level) throws java.io.IOException {
        java.awt.image.BufferedImage src = javax.imageio.ImageIO.read(
            new java.io.ByteArrayInputStream(imageBytes));
        if (src == null) throw new java.io.IOException("Formato de imagen no soportado");

        java.awt.image.BufferedImage small = new java.awt.image.BufferedImage(
            level, level, java.awt.image.BufferedImage.TYPE_INT_RGB);
        java.awt.Graphics2D g = small.createGraphics();
        g.drawImage(src, 0, 0, level, level, null);
        g.dispose();

        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        javax.imageio.ImageIO.write(small, "png", out);
        return out.toByteArray();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Estadísticas
    // ══════════════════════════════════════════════════════════════════════════

    public Map<String, Object> userStats(User user) {
        Map<String, Object> stats = new HashMap<>();
        for (boolean practice : new boolean[] {false, true}) {
            Map<String, Object> byMode = new HashMap<>();
            for (QuizMode mode : QuizMode.values()) {
                byMode.put(mode.name(), Map.of(
                    "played", quizGameRepository
                        .countByUserAndModeAndPracticeAndFinishedTrue(user, mode, practice),
                    "won", quizGameRepository
                        .countByUserAndModeAndPracticeAndSolvedTrue(user, mode, practice)
                ));
            }
            stats.put(practice ? "practice" : "daily", byMode);
        }
        return stats;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Selección del reto diario
    // ══════════════════════════════════════════════════════════════════════════

    private QuizDaily getOrCreateDaily(QuizMode mode) {
        LocalDate today = LocalDate.now();
        return quizDailyRepository.findByDateAndMode(today, mode)
            .orElseGet(() -> createDaily(today, mode));
    }

    /**
     * Elección con dos exclusiones:
     *  1. DURA: las canciones que ya son el reto de HOY en otro modo — cada modo
     *     debe tener su propia canción (mientras el pool dé para tantos modos).
     *  2. BLANDA: las usadas por este modo en los últimos {@link #NO_REPEAT_DAYS}
     *     días, para no repetir; si no queda nada, se relaja.
     * La semilla por fecha+modo (bien mezclada — semillas consecutivas de
     * java.util.Random dan primeros valores correlacionados) mantiene la
     * elección estable ante carreras; la unique constraint remata el empate.
     */
    private synchronized QuizDaily createDaily(LocalDate date, QuizMode mode) {
        Optional<QuizDaily> existing = quizDailyRepository.findByDateAndMode(date, mode);
        if (existing.isPresent()) return existing.get();

        List<QuizSong> eligible = eligibleSongs(mode);
        if (eligible.isEmpty()) {
            throw new RuntimeException(
                "El pool del quiz aún no tiene canciones jugables para este modo. " +
                "Pide a un administrador que importe canciones.");
        }

        Set<Long> todaysOtherModes = quizDailyRepository.findByDate(date).stream()
            .map(d -> d.getSong().getId())
            .collect(Collectors.toSet());

        Set<Long> recentIds = quizDailyRepository
            .findByModeAndDateAfter(mode, date.minusDays(NO_REPEAT_DAYS)).stream()
            .map(d -> d.getSong().getId())
            .collect(Collectors.toSet());

        // Ambas exclusiones → solo la dura → sin exclusiones (pool minúsculo)
        List<QuizSong> candidates = eligible.stream()
            .filter(s -> !todaysOtherModes.contains(s.getId()) && !recentIds.contains(s.getId()))
            .toList();
        if (candidates.isEmpty()) {
            candidates = eligible.stream()
                .filter(s -> !todaysOtherModes.contains(s.getId()))
                .toList();
        }
        if (candidates.isEmpty()) candidates = eligible;

        // Mezcla multiplicativa (constante áurea) para dispersar semillas vecinas
        long seed = (date.toEpochDay() * 31 + mode.ordinal()) * 0x9E3779B97F4A7C15L;
        QuizSong pick = candidates.get(new Random(seed).nextInt(candidates.size()));

        QuizDaily daily = new QuizDaily();
        daily.setDate(date);
        daily.setMode(mode);
        daily.setSong(pick);
        try {
            return quizDailyRepository.save(daily);
        } catch (Exception e) {
            return quizDailyRepository.findByDateAndMode(date, mode)
                .orElseThrow(() -> new RuntimeException("No se pudo crear el reto diario"));
        }
    }

    private List<QuizSong> eligibleSongs(QuizMode mode) {
        return switch (mode) {
            case CLASSIC -> quizSongRepository.findClassicEligible();
            case AUDIO   -> quizSongRepository.findAudioEligible();
            case COVER   -> quizSongRepository.findCoverEligible();
            case EMOJI   -> quizSongRepository.findEmojiEligible();
            // El mínimo de líneas no se puede comprobar en JPQL → filtro aquí
            case LYRICS  -> quizSongRepository.findLyricsCandidates().stream()
                                .filter(QuizSong::isLyricsEligible)
                                .toList();
        };
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Construcción del estado para el cliente
    // ══════════════════════════════════════════════════════════════════════════

    private QuizGame ownedGame(User user, Long gameId) {
        QuizGame game = quizGameRepository.findById(gameId)
            .orElseThrow(() -> new NotFoundException("Partida no encontrada"));
        if (!game.getUser().getId().equals(user.getId())) {
            throw new ForbiddenException("Esta partida no es tuya");
        }
        return game;
    }

    private QuizGameStateResponse buildState(QuizGame game) {
        List<QuizGuess> guesses = quizGuessRepository.findByGameOrderByGuessOrderAsc(game);
        QuizSong secret = game.getSecretSong();

        QuizGameStateResponse state = new QuizGameStateResponse();
        state.setGameId(game.getId());
        state.setMode(game.getMode().name());
        state.setPractice(game.isPractice());
        state.setFinished(game.isFinished());
        state.setSolved(game.isSolved());
        state.setAttemptsUsed(guesses.size());

        if (game.getDaily() != null) {
            state.setDate(game.getDaily().getDate().toString());
            state.setDailySolvedCount(quizGameRepository.countByDailyAndSolvedTrue(game.getDaily()));
        }

        if (game.getMode().isClueMode()) {
            state.setMaxAttempts(CLUE_MAX_ATTEMPTS);
        }

        switch (game.getMode()) {
            case CLASSIC -> state.setHints(buildHints(game, guesses.size()));

            case AUDIO -> {
                state.setSnippetSteps(SNIPPET_STEPS);
                int step = Math.min(guesses.size(), SNIPPET_STEPS.size() - 1);
                state.setUnlockedSeconds(game.isFinished() ? 30 : SNIPPET_STEPS.get(step));
            }

            case LYRICS -> {
                // attempts+1 líneas visibles (la 1ª es gratis); sin censura al terminar
                int visible = Math.min(guesses.size() + 1, CLUE_MAX_ATTEMPTS);
                state.setLyricsLines(lyricsClue(secret, visible, !game.isFinished()));
            }

            case COVER -> { /* la pista viaja por el proxy /games/{id}/cover */ }

            case EMOJI -> {
                List<String> all = splitEmojis(secret.getEmojis());
                int visible = game.isFinished()
                    ? all.size()
                    : Math.min(guesses.size() + 1, all.size());
                state.setEmojisVisible(String.join(" ", all.subList(0, visible)));
                state.setEmojisTotal(all.size());
            }
        }

        state.setGuesses(guesses.stream()
            .map(g -> buildGuessView(game, secret, g))
            .toList());

        if (game.isFinished()) {
            state.setAnswer(QuizSongResponse.forReveal(secret));
            // Puntos de ranking de esta partida (solo diaria; la práctica no puntúa)
            if (!game.isPractice()) state.setPointsEarned(game.getPoints());
        }
        return state;
    }

    private Hints buildHints(QuizGame game, int attempts) {
        int wrongAttempts = game.isSolved() ? attempts - 1 : attempts;
        QuizSong secret = game.getSecretSong();

        Hints hints = new Hints();
        hints.setCoverUnlockAt(HINT_COVER_AT);
        hints.setTitleUnlockAt(HINT_TITLE_AT);
        if (wrongAttempts >= HINT_COVER_AT) hints.setCoverUrl(secret.getCoverUrl());
        if (wrongAttempts >= HINT_TITLE_AT) hints.setTitleHint(maskedTitle(secret.getTitle()));
        return hints;
    }

    // ── Pista del modo letra ──────────────────────────────────────────────────

    /**
     * Devuelve las primeras {@code visible} líneas de la ventana de letra de la
     * canción, censurando las palabras del título para no regalar la respuesta.
     * La ventana (qué trozo de la letra se enseña) es determinista por canción.
     */
    static List<String> lyricsClue(QuizSong secret, int visible, boolean censor) {
        List<String> lines = secret.getLyrics() == null ? List.of()
            : secret.getLyrics().lines().filter(l -> !l.isBlank()).map(String::trim).toList();
        if (lines.isEmpty()) return List.of();

        // Ventana de 6 líneas, empezando lejos del principio (ahí suele estar el título)
        int span = Math.min(CLUE_MAX_ATTEMPTS, lines.size());
        int maxStart = lines.size() - span;
        int start = maxStart <= 0 ? 0
            : Math.min(maxStart, 2 + new Random(secret.getId() * 7).nextInt(maxStart + 1));

        return lines.subList(start, start + Math.min(visible, span)).stream()
            .map(line -> censor ? censorTitle(line, secret.getTitle()) : line)
            .toList();
    }

    /** Palabras demasiado comunes para censurarlas aunque estén en el título. */
    private static final Set<String> CENSOR_STOPWORDS = Set.of(
        "the", "a", "an", "and", "or", "of", "in", "on", "with", "to", "you", "me",
        "my", "your", "it", "is", "i", "we",
        "de", "la", "el", "los", "las", "un", "una", "y", "o", "en", "con",
        "mi", "tu", "te", "yo", "que", "no", "se", "del", "al");

    private static final java.util.regex.Pattern WORD =
        java.util.regex.Pattern.compile("[\\p{L}\\p{N}']+");

    /** Sustituye en la línea las palabras del título por "____" (sin distinguir tildes). */
    static String censorTitle(String line, String title) {
        if (line == null || title == null) return line;

        Set<String> titleTokens = new java.util.HashSet<>();
        java.util.regex.Matcher t = WORD.matcher(title);
        while (t.find()) {
            String token = normalizeWord(t.group());
            if (token.length() >= 2 && !CENSOR_STOPWORDS.contains(token)) {
                titleTokens.add(token);
            }
        }
        if (titleTokens.isEmpty()) return line;

        StringBuilder sb = new StringBuilder();
        java.util.regex.Matcher m = WORD.matcher(line);
        while (m.find()) {
            String replacement = titleTokens.contains(normalizeWord(m.group()))
                ? "____" : m.group();
            m.appendReplacement(sb, java.util.regex.Matcher.quoteReplacement(replacement));
        }
        m.appendTail(sb);
        return sb.toString();
    }

    private static String normalizeWord(String word) {
        return java.text.Normalizer.normalize(word.toLowerCase(), java.text.Normalizer.Form.NFD)
            .replaceAll("\\p{M}", "");
    }

    // ── Pista del modo emoji ──────────────────────────────────────────────────

    /**
     * Trocea el campo emojis. Los admins los guardan separados por espacios;
     * si no hay espacios, se trocea por clústeres de grafemas (emojis ZWJ
     * incluidos) con BreakIterator.
     */
    static List<String> splitEmojis(String emojis) {
        if (emojis == null || emojis.isBlank()) return List.of();
        String trimmed = emojis.trim();

        if (trimmed.contains(" ")) {
            return java.util.Arrays.stream(trimmed.split("\\s+"))
                .filter(s -> !s.isBlank())
                .toList();
        }

        List<String> glyphs = new java.util.ArrayList<>();
        java.text.BreakIterator it = java.text.BreakIterator.getCharacterInstance();
        it.setText(trimmed);
        int start = it.first();
        for (int end = it.next(); end != java.text.BreakIterator.DONE; start = end, end = it.next()) {
            glyphs.add(trimmed.substring(start, end));
        }
        return glyphs;
    }

    /** "Bohemian Rhapsody" → "B······· R·······" (se ve la inicial y la forma). */
    static String maskedTitle(String title) {
        if (title == null || title.isEmpty()) return "";
        StringBuilder sb = new StringBuilder();
        boolean first = true;
        for (char c : title.toCharArray()) {
            if (Character.isLetterOrDigit(c)) {
                sb.append(first ? c : '·');
                first = false;
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    private GuessView buildGuessView(QuizGame game, QuizSong secret, QuizGuess guess) {
        GuessView view = new GuessView();
        QuizSong song = guess.getGuessedSong();

        if (song == null) {
            view.setSkipped(true);
            return view;
        }

        view.setSong(QuizSongResponse.forAutocomplete(song));
        view.setCorrect(song.getId().equals(secret.getId()));

        if (game.getMode().isClueMode()) {
            view.setArtistMatch(equalsIgnoreCaseSafe(song.getArtistName(), secret.getArtistName()));
        } else {
            view.setArtist(compareText(song.getArtistName(), secret.getArtistName()));
            view.setGenre(compareText(song.getGenre(), secret.getGenre()));
            view.setYear(compareNumber(song.getReleaseYear(), secret.getReleaseYear(), 0, 5));
            view.setDuration(compareNumber(song.getDurationSec(), secret.getDurationSec(), 5, 20));
            view.setExplicit(compareExplicit(song.getExplicit(), secret.getExplicit()));
        }
        return view;
    }

    // ── Comparadores de casillas ──────────────────────────────────────────────

    private FieldView compareText(String guessValue, String secretValue) {
        String status = equalsIgnoreCaseSafe(guessValue, secretValue) ? "CORRECT" : "WRONG";
        return FieldView.of(guessValue != null ? guessValue : "?", status, null);
    }

    /**
     * Compara números con dos umbrales: |diff| <= correctTolerance → CORRECT,
     * |diff| <= closeTolerance → CLOSE, si no WRONG. La dirección apunta hacia
     * la respuesta (HIGHER = la respuesta es mayor que tu intento).
     */
    private FieldView compareNumber(Integer guessValue, Integer secretValue,
                                    int correctTolerance, int closeTolerance) {
        if (guessValue == null || secretValue == null) {
            return FieldView.of(guessValue != null ? guessValue.toString() : "?", "WRONG", null);
        }
        int diff = secretValue - guessValue;
        String status = Math.abs(diff) <= correctTolerance ? "CORRECT"
                      : Math.abs(diff) <= closeTolerance   ? "CLOSE"
                      : "WRONG";
        String direction = "CORRECT".equals(status) ? "EQUAL"
                         : diff > 0 ? "HIGHER" : "LOWER";
        return FieldView.of(guessValue.toString(), status, direction);
    }

    private FieldView compareExplicit(Boolean guessValue, Boolean secretValue) {
        boolean guess  = Boolean.TRUE.equals(guessValue);
        boolean secretFlag = Boolean.TRUE.equals(secretValue);
        return FieldView.of(String.valueOf(guess),
            guess == secretFlag ? "CORRECT" : "WRONG", null);
    }

    private static boolean equalsIgnoreCaseSafe(String a, String b) {
        return a != null && b != null && a.trim().equalsIgnoreCase(b.trim());
    }
}
