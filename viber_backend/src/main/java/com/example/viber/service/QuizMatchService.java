package com.example.viber.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import com.example.viber.dto.CreateMatchRequest;
import com.example.viber.exception.ErrorCode;
import com.example.viber.exception.ConflictException;
import com.example.viber.exception.ForbiddenException;
import com.example.viber.exception.NotFoundException;
import com.example.viber.model.ChatGroup;
import com.example.viber.model.Friendship;
import com.example.viber.model.GroupMember;
import com.example.viber.model.QuizMatch;
import com.example.viber.model.QuizMatchResult;
import com.example.viber.model.QuizMode;
import com.example.viber.model.QuizSong;
import com.example.viber.model.User;
import com.example.viber.repository.FriendshipRepository;
import com.example.viber.repository.GroupMemberRepository;
import com.example.viber.repository.QuizMatchRepository;
import com.example.viber.repository.QuizMatchResultRepository;
import com.example.viber.repository.QuizSongRepository;
import com.example.viber.repository.UserRepository;

/**
 * Motor de las partidas de quiz EN VIVO (competición tipo Kahoot), tanto 1v1 en
 * un DM como todos-contra-todos en un grupo.
 *
 * <p>El estado en directo (sala de espera, ronda actual, puntuaciones y
 * temporizadores) vive en MEMORIA en un {@link ConcurrentHashMap}; solo la
 * cabecera y el resultado final se persisten ({@link QuizMatch} /
 * {@link QuizMatchResult}). Encaja con el broker STOMP en memoria que ya usa la
 * app — una sola instancia de servidor.
 *
 * <p>Máquina de estados de cada partida:
 * {@code LOBBY → (start) → ronda 1 … ronda N → FINISHED}. Cada ronda emite una
 * pregunta de opción múltiple (4 candidatas) y, al agotarse el tiempo o cuando
 * todos responden, una revelación con la respuesta y el marcador. La puntuación
 * premia acertar y la rapidez.
 *
 * <p>Canales STOMP:
 * <ul>
 *   <li>broadcast → {@code /topic/quizmatch.{id}} (lobby, pregunta, revelación, final)</li>
 *   <li>invitación personal → {@code /user/{username}/queue/quizmatch}</li>
 *   <li>cliente → {@code /app/quizmatch.{id}.join | .start | .answer} (ver el WebSocketController)</li>
 * </ul>
 */
@Service
public class QuizMatchService {

    private static final Logger log = LoggerFactory.getLogger(QuizMatchService.class);

    private static final int MIN_OPTIONS      = 4;     // candidatas por pregunta
    private static final int DEFAULT_ROUNDS    = 5;
    private static final int MAX_ROUNDS        = 10;
    private static final int DEFAULT_SECONDS    = 15;
    private static final int MIN_SECONDS        = 5;
    private static final int MAX_SECONDS        = 30;
    private static final long REVEAL_PAUSE_MS   = 4000;  // pausa para ver el resultado
    private static final long CLEANUP_DELAY_MS  = 60_000;

    private final Map<Long, LiveMatch> matches = new ConcurrentHashMap<>();
    private final ScheduledExecutorService scheduler =
        Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "quiz-match-scheduler");
            t.setDaemon(true);
            return t;
        });

    @Autowired private QuizMatchRepository       matchRepository;
    @Autowired private QuizMatchResultRepository resultRepository;
    @Autowired private QuizSongRepository        songRepository;
    @Autowired private UserRepository            userRepository;
    @Autowired private FriendshipRepository      friendshipRepository;
    @Autowired private GroupMemberRepository     groupMemberRepository;
    @Autowired private GroupService              groupService;
    @Autowired private DeezerService             deezerService;
    @Autowired private FirestoreDirectMessageService dmService;
    @Autowired private SimpMessagingTemplate     messaging;

    // Para descargar el preview MP3 por proxy (modo audio), con timeouts.
    private final org.springframework.web.client.RestTemplate restTemplate = buildRestTemplate();

    private static org.springframework.web.client.RestTemplate buildRestTemplate() {
        var factory = new org.springframework.http.client.SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5_000);
        factory.setReadTimeout(15_000);
        return new org.springframework.web.client.RestTemplate(factory);
    }

    // ── Creación ────────────────────────────────────────────────────────────────

    /** Crea una partida en sala de espera e invita a los rivales. Devuelve el resumen inicial. */
    public Map<String, Object> createMatch(CreateMatchRequest req, String hostUsername) {
        User host = requireUser(hostUsername);

        QuizMode mode = parseMode(req.getMode());
        int rounds  = clamp(req.getTotalRounds()    == null ? DEFAULT_ROUNDS  : req.getTotalRounds(), 1, MAX_ROUNDS);
        int seconds = clamp(req.getSecondsPerRound() == null ? DEFAULT_SECONDS : req.getSecondsPerRound(), MIN_SECONDS, MAX_SECONDS);

        // Pool elegible para el modo elegido (todas tienen título + artista para las opciones)
        List<QuizSong> pool = new ArrayList<>(eligiblePool(mode));
        if (pool.size() < MIN_OPTIONS)
            throw new ConflictException(
                "No hay suficientes canciones en el pool para este modo (mínimo " + MIN_OPTIONS + ")");
        if (rounds > pool.size()) rounds = pool.size();   // sin repetir canción secreta

        // Determinar alcance e invitados
        String scope = req.getScope() == null ? "" : req.getScope().trim().toUpperCase();
        Set<String> allowed = new LinkedHashSet<>();
        Set<String> invitees = new LinkedHashSet<>();
        Long groupId = null;
        String dmOther = null;

        if ("DM".equals(scope)) {
            User other = requireUser(req.getOtherUsername());
            if (other.getId().equals(host.getId()))
                throw new RuntimeException("No puedes retarte a ti mismo");
            if (!areFriends(host, other))
                throw new ForbiddenException("Solo puedes retar a tus amigos");
            allowed.add(host.getUsername());
            allowed.add(other.getUsername());
            invitees.add(other.getUsername());
            dmOther = other.getUsername();
        } else if ("GROUP".equals(scope)) {
            if (req.getGroupId() == null) throw new RuntimeException("Falta el groupId");
            ChatGroup group = groupService.requireGroup(req.getGroupId());
            GroupMember member = groupService.requireMembership(group, host);
            if (!group.getStartQuizPolicy().allows(member.getRole()))
                throw new ForbiddenException("No tienes permiso para lanzar un quiz en este grupo");
            groupId = group.getId();
            for (GroupMember gm : groupMemberRepository.findByGroup(group)) {
                String u = gm.getUser().getUsername();
                allowed.add(u);
                if (!u.equals(host.getUsername())) invitees.add(u);
            }
            if (invitees.isEmpty())
                throw new ConflictException("El grupo no tiene a nadie más a quien retar");
        } else {
            throw new RuntimeException("Alcance no válido (usa DM o GROUP)");
        }

        // Cabecera persistida (genera el id de la partida)
        QuizMatch entity = new QuizMatch();
        entity.setMode(mode);
        entity.setScope(scope);
        entity.setGroupId(groupId);
        entity.setCreator(host);
        entity.setTotalRounds(rounds);
        entity.setSecondsPerRound(seconds);
        entity.setStatus("LOBBY");
        entity = matchRepository.save(entity);

        // Estado en vivo
        LiveMatch m = new LiveMatch(entity.getId(), mode, scope, groupId,
            host.getUsername(), rounds, seconds, pool, allowed);
        Collections.shuffle(m.pool);
        for (int i = 0; i < rounds; i++) m.secrets.add(m.pool.get(i));
        m.players.add(host.getUsername());
        matches.put(m.id, m);

        // Invitar a los rivales por su cola personal
        Map<String, Object> invite = new HashMap<>();
        invite.put("type",      "INVITE");
        invite.put("matchId",   m.id);
        invite.put("mode",      mode.name());
        invite.put("scope",     scope);
        invite.put("groupId",   groupId);
        invite.put("from",      host.getUsername());
        invite.put("totalRounds", rounds);
        invite.put("secondsPerRound", seconds);
        for (String u : invitees)
            messaging.convertAndSendToUser(u, "/queue/quizmatch", invite);

        // Postear el reto como mensaje en el chat (con botón "Unirse" en el cliente)
        postChallengeToChat(scope, host.getUsername(), dmOther, groupId, m.id, mode.name(), rounds);

        Map<String, Object> result = new HashMap<>();
        result.put("matchId", m.id);
        result.put("mode", mode.name());
        result.put("scope", scope);
        result.put("totalRounds", rounds);
        result.put("secondsPerRound", seconds);
        result.put("host", host.getUsername());
        return result;
    }

    /**
     * Publica el reto como un mensaje en el chat (DM o grupo). El cliente lo
     * pinta como una tarjeta con la info de la partida y un botón "Unirse".
     */
    private void postChallengeToChat(String scope, String host, String dmOther,
                                     Long groupId, long matchId, String mode, int rounds) {
        String text = host + " ha lanzado un duelo de quiz";
        if ("GROUP".equals(scope) && groupId != null) {
            try {
                groupService.postQuizChallenge(groupId, host, matchId, mode, rounds);
            } catch (Exception e) {
                log.warn("No se pudo postear el reto en el grupo {}: {}", groupId, e.getMessage());
            }
        } else if ("DM".equals(scope) && dmOther != null) {
            long ts = System.currentTimeMillis();
            dmService.sendChallenge(host, dmOther, matchId, mode, rounds);
            Map<String, Object> payload = new HashMap<>();
            payload.put("sender", host);
            payload.put("text", text);
            payload.put("timestamp", ts);
            payload.put("type", "QUIZ_CHALLENGE");
            payload.put("matchId", matchId);
            payload.put("mode", mode);
            payload.put("totalRounds", rounds);
            payload.put("to", dmOther);
            messaging.convertAndSendToUser(dmOther, "/queue/dm", payload);
            messaging.convertAndSendToUser(host,    "/queue/dm", payload);
        }
    }

    // ── Eventos del cliente (vía WebSocket) ─────────────────────────────────────

    public void join(Long matchId, String username) {
        LiveMatch m = matches.get(matchId);
        if (m == null) return;
        synchronized (m) {
            if (!"LOBBY".equals(m.status)) { broadcastLobby(m); return; }
            if (!m.allowed.contains(username)) return;
            m.players.add(username);
            broadcastLobby(m);
        }
    }

    public void leaveLobby(Long matchId, String username) {
        LiveMatch m = matches.get(matchId);
        if (m == null) return;
        synchronized (m) {
            if ("LOBBY".equals(m.status) && m.players.remove(username)) broadcastLobby(m);
        }
    }

    public void start(Long matchId, String username) {
        LiveMatch m = matches.get(matchId);
        if (m == null) return;
        synchronized (m) {
            if (!"LOBBY".equals(m.status)) return;
            if (!m.host.equals(username)) return;            // solo el anfitrión arranca
            if (m.players.size() < 2) return;                // se necesitan ≥2 jugadores
            m.status = "RUNNING";
            m.scoringPlayers = new LinkedHashSet<>(m.players);
            for (String p : m.scoringPlayers) {
                m.scores.put(p, 0);
                m.correctCounts.put(p, 0);
            }
            updateStatus(m.id, "RUNNING");
            startRound(m, 0);
        }
    }

    public void answer(Long matchId, String username, Long optionId) {
        LiveMatch m = matches.get(matchId);
        if (m == null || optionId == null) return;
        synchronized (m) {
            if (!"RUNNING".equals(m.status) || m.roundEnded) return;
            if (!m.scoringPlayers.contains(username)) return;
            if (m.answers.containsKey(username)) return;     // ya respondió esta ronda
            long now = System.currentTimeMillis();
            if (now > m.roundEndsMs) return;

            boolean correct = m.secret != null && optionId.equals(m.secret.getId());
            int delta = 0;
            if (correct) {
                double remaining = Math.max(0.0,
                    (m.roundEndsMs - now) / (double) (m.secondsPerRound * 1000L));
                delta = 500 + (int) Math.round(500 * remaining);   // 500 base + hasta 500 por rapidez
                m.scores.merge(username, delta, Integer::sum);
                m.correctCounts.merge(username, 1, Integer::sum);
            }
            m.answers.put(username, new PlayerAnswer(optionId, correct, delta));

            // Si todos han respondido, cerrar la ronda ya
            if (m.answers.size() >= m.scoringPlayers.size()) {
                cancelTimer(m);
                endRound(m);
            }
        }
    }

    /**
     * Preview MP3 de la canción secreta de la ronda actual, servido por proxy
     * (modo audio). Solo lo pueden pedir los jugadores de la partida y nunca
     * expone la URL de Deezer al cliente, igual que el quiz individual.
     */
    public byte[] roundAudio(Long matchId, String username) {
        LiveMatch m = matches.get(matchId);
        if (m == null) throw new NotFoundException("La partida ya no existe");
        QuizSong secret;
        synchronized (m) {
            if (!m.allowed.contains(username))
                throw new ForbiddenException("No participas en esta partida");
            if (m.mode != QuizMode.AUDIO)
                throw new RuntimeException("Esta partida no es del modo audio");
            secret = m.secret;
        }
        if (secret == null)
            throw new NotFoundException("Aún no hay ronda en curso");

        String url = deezerService.freshPreviewUrl(secret.getDeezerTrackId())
            .orElse(secret.getPreviewUrl());
        if (url == null || url.isBlank())
            throw new NotFoundException("La canción no tiene preview disponible");
        try {
            // URI.create evita que RestTemplate re-encodee la firma de la URL
            byte[] bytes = restTemplate.getForObject(java.net.URI.create(url), byte[].class);
            if (bytes == null || bytes.length == 0)
                throw new RuntimeException("Deezer devolvió un preview vacío");
            return bytes;
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException("No se pudo descargar el preview: " + e.getMessage());
        }
    }

    /** Snapshot de la sala de espera para un cliente que abre la pantalla. */
    public Map<String, Object> lobbySnapshot(Long matchId) {
        LiveMatch m = matches.get(matchId);
        if (m == null) throw new NotFoundException("La partida ya no existe");
        synchronized (m) { return lobbyPayload(m); }
    }

    // ── Ciclo de ronda ──────────────────────────────────────────────────────────

    private void startRound(LiveMatch m, int index) {
        m.roundIndex = index;
        m.secret = m.secrets.get(index);
        m.options = buildOptions(m, m.secret);
        m.answers = new HashMap<>();
        m.roundEnded = false;
        m.roundStartMs = System.currentTimeMillis();
        m.roundEndsMs  = m.roundStartMs + m.secondsPerRound * 1000L;

        broadcastQuestion(m);

        m.timer = scheduler.schedule(() -> {
            synchronized (m) {
                if (!m.roundEnded && "RUNNING".equals(m.status)) endRound(m);
            }
        }, m.secondsPerRound, TimeUnit.SECONDS);
    }

    private void endRound(LiveMatch m) {
        if (m.roundEnded) return;
        m.roundEnded = true;

        broadcastReveal(m);

        boolean last = m.roundIndex + 1 >= m.secrets.size();
        scheduler.schedule(() -> {
            synchronized (m) {
                if (!"RUNNING".equals(m.status)) return;
                if (last) finish(m);
                else      startRound(m, m.roundIndex + 1);
            }
        }, REVEAL_PAUSE_MS, TimeUnit.MILLISECONDS);
    }

    private void finish(LiveMatch m) {
        m.status = "FINISHED";
        List<Map<String, Object>> standings = standings(m);
        String winner = standings.isEmpty() ? null : (String) standings.get(0).get("username");

        persistResults(m, standings, winner);

        Map<String, Object> payload = new HashMap<>();
        payload.put("type", "FINAL");
        payload.put("standings", standings);
        payload.put("winner", winner);
        messaging.convertAndSend("/topic/quizmatch." + m.id, (Object) payload);

        // Guardar el resultado como tarjeta en el chat, con la clasificación
        postResultToChat(m, standings, winner);

        scheduler.schedule(() -> matches.remove(m.id), CLEANUP_DELAY_MS, TimeUnit.MILLISECONDS);
    }

    /**
     * Postea la clasificación final como mensaje (tipo QUIZ_RESULT) en el chat de
     * origen. La clasificación viaja embebida en el mensaje, así que se conserva
     * aunque la partida en memoria ya se haya limpiado.
     */
    private void postResultToChat(LiveMatch m, List<Map<String, Object>> standings, String winner) {
        if (winner == null) return;
        try {
            if ("GROUP".equals(m.scope) && m.groupId != null) {
                groupService.postQuizResult(m.groupId, m.id, winner, standings);
            } else if ("DM".equals(m.scope)) {
                String host  = m.host;
                String other = m.allowed.stream()
                    .filter(u -> !u.equals(host)).findFirst().orElse(null);
                if (other == null) return;
                long ts = System.currentTimeMillis();
                dmService.sendResult(host, other, m.id, winner, standings);
                Map<String, Object> payload = resultPayload(m.id, host, winner, standings, ts);
                payload.put("to", other);
                messaging.convertAndSendToUser(other, "/queue/dm", payload);
                messaging.convertAndSendToUser(host,  "/queue/dm", payload);
            }
        } catch (Exception e) {
            log.warn("No se pudo postear el resultado de la partida {}: {}", m.id, e.getMessage());
        }
    }

    static Map<String, Object> resultPayload(long matchId, String sender, String winner,
                                             List<Map<String, Object>> standings, long ts) {
        Map<String, Object> p = new HashMap<>();
        p.put("sender",    sender);
        p.put("text",      "Quiz terminado — ganó " + winner);
        p.put("timestamp", ts);
        p.put("type",      "QUIZ_RESULT");
        p.put("matchId",   matchId);
        p.put("winner",    winner);
        p.put("standings", standings);
        return p;
    }

    // ── Construcción de payloads ────────────────────────────────────────────────

    private List<MatchOption> buildOptions(LiveMatch m, QuizSong secret) {
        List<QuizSong> distractors = new ArrayList<>(m.pool);
        distractors.removeIf(s -> s.getId().equals(secret.getId()));
        Collections.shuffle(distractors);

        List<QuizSong> chosen = new ArrayList<>();
        chosen.add(secret);
        for (QuizSong s : distractors) {
            if (chosen.size() >= MIN_OPTIONS) break;
            chosen.add(s);
        }
        Collections.shuffle(chosen);

        List<MatchOption> options = new ArrayList<>();
        for (QuizSong s : chosen)
            options.add(new MatchOption(s.getId(), s.getTitle(), s.getArtistName()));
        return options;
    }

    private void broadcastQuestion(LiveMatch m) {
        Map<String, Object> p = new HashMap<>();
        p.put("type", "QUESTION");
        p.put("round", m.roundIndex + 1);
        p.put("totalRounds", m.secrets.size());
        p.put("mode", m.mode.name());

        // La pista se rellena según el modo (el cliente la pinta directamente).
        // En AUDIO no se manda la URL (delataría la canción): el cliente pide el
        // preview por proxy a /api/quiz/match/{id}/audio.
        switch (m.mode) {
            case EMOJI  -> p.put("clueText", m.secret.getEmojis());
            case LYRICS -> p.put("clueText", lyricClue(m.secret));
            case COVER  -> p.put("clueImageUrl", m.secret.getCoverUrl());
            case AUDIO  -> p.put("clueAudio", true);
            default     -> { /* CLASSIC no se usa en vivo */ }
        }

        List<Map<String, Object>> opts = new ArrayList<>();
        for (MatchOption o : m.options) {
            Map<String, Object> om = new HashMap<>();
            om.put("id", o.id);
            om.put("title", o.title);
            om.put("artist", o.artist);
            opts.add(om);
        }
        p.put("options", opts);
        p.put("endsAt", m.roundEndsMs);
        p.put("serverNow", System.currentTimeMillis());
        messaging.convertAndSend("/topic/quizmatch." + m.id, (Object) p);
    }

    private void broadcastReveal(LiveMatch m) {
        Map<String, Object> p = new HashMap<>();
        p.put("type", "REVEAL");
        p.put("round", m.roundIndex + 1);
        p.put("correctOptionId", m.secret.getId());

        Map<String, Object> correct = new HashMap<>();
        correct.put("title", m.secret.getTitle());
        correct.put("artist", m.secret.getArtistName());
        correct.put("coverUrl", m.secret.getCoverUrl());
        p.put("correct", correct);

        List<Map<String, Object>> results = new ArrayList<>();
        for (String u : m.scoringPlayers) {
            PlayerAnswer a = m.answers.get(u);
            Map<String, Object> rm = new HashMap<>();
            rm.put("username", u);
            rm.put("answered", a != null);
            rm.put("correct", a != null && a.correct);
            rm.put("roundScore", a != null ? a.delta : 0);
            rm.put("totalScore", m.scores.getOrDefault(u, 0));
            rm.put("correctCount", m.correctCounts.getOrDefault(u, 0));
            results.add(rm);
        }
        p.put("results", results);
        p.put("scoreboard", standings(m));
        p.put("last", m.roundIndex + 1 >= m.secrets.size());
        p.put("nextInSeconds", (int) (REVEAL_PAUSE_MS / 1000));
        messaging.convertAndSend("/topic/quizmatch." + m.id, (Object) p);
    }

    private void broadcastLobby(LiveMatch m) {
        messaging.convertAndSend("/topic/quizmatch." + m.id, (Object) lobbyPayload(m));
    }

    private Map<String, Object> lobbyPayload(LiveMatch m) {
        Map<String, Object> p = new HashMap<>();
        p.put("type", "LOBBY");
        p.put("matchId", m.id);
        p.put("host", m.host);
        p.put("mode", m.mode.name());
        p.put("scope", m.scope);
        p.put("totalRounds", m.secrets.size());
        p.put("secondsPerRound", m.secondsPerRound);
        p.put("players", new ArrayList<>(m.players));
        p.put("status", m.status);
        return p;
    }

    private List<Map<String, Object>> standings(LiveMatch m) {
        List<String> ranked = new ArrayList<>(m.scoringPlayers != null ? m.scoringPlayers : m.players);
        ranked.sort((a, b) -> Integer.compare(
            m.scores.getOrDefault(b, 0), m.scores.getOrDefault(a, 0)));
        List<Map<String, Object>> out = new ArrayList<>();
        int pos = 1;
        for (String u : ranked) {
            Map<String, Object> row = new HashMap<>();
            row.put("position", pos++);
            row.put("username", u);
            row.put("score", m.scores.getOrDefault(u, 0));
            row.put("correctCount", m.correctCounts.getOrDefault(u, 0));
            out.add(row);
        }
        return out;
    }

    // ── Persistencia del resultado ──────────────────────────────────────────────

    private void persistResults(LiveMatch m, List<Map<String, Object>> standings, String winner) {
        try {
            QuizMatch entity = matchRepository.findById(m.id).orElse(null);
            if (entity != null) {
                entity.setStatus("FINISHED");
                entity.setWinnerUsername(winner);
                entity.setFinishedAt(LocalDateTime.now());
                matchRepository.save(entity);

                for (Map<String, Object> row : standings) {
                    User u = userRepository.findByUsername((String) row.get("username")).orElse(null);
                    if (u == null) continue;
                    QuizMatchResult r = new QuizMatchResult();
                    r.setMatch(entity);
                    r.setUser(u);
                    r.setScore((Integer) row.get("score"));
                    r.setCorrectCount((Integer) row.get("correctCount"));
                    r.setPosition((Integer) row.get("position"));
                    resultRepository.save(r);
                }
            }
        } catch (Exception e) {
            log.error("Error persistiendo resultados de la partida {}: {}", m.id, e.getMessage());
        }
    }

    private void updateStatus(Long id, String status) {
        try {
            matchRepository.findById(id).ifPresent(e -> {
                e.setStatus(status);
                matchRepository.save(e);
            });
        } catch (Exception e) {
            log.warn("No se pudo actualizar el estado de la partida {}: {}", id, e.getMessage());
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private List<QuizSong> eligiblePool(QuizMode mode) {
        return switch (mode) {
            case EMOJI  -> songRepository.findEmojiEligible();
            case COVER  -> songRepository.findCoverEligible();
            case AUDIO  -> songRepository.findAudioEligible();
            case LYRICS -> songRepository.findLyricsCandidates().stream()
                                .filter(QuizSong::isLyricsEligible).toList();
            default     -> List.of();
        };
    }

    /** Una línea aleatoria de la letra con el título censurado. */
    private static String lyricClue(QuizSong song) {
        List<String> lines = song.getLyrics().lines()
            .map(String::trim).filter(l -> !l.isBlank()).toList();
        if (lines.isEmpty()) return "…";
        String line = lines.get(new java.util.Random().nextInt(lines.size()));
        String title = song.getTitle();
        if (title != null && !title.isBlank())
            line = line.replaceAll("(?i)" + java.util.regex.Pattern.quote(title), "▢▢▢");
        return line;
    }

    private void cancelTimer(LiveMatch m) {
        if (m.timer != null) { m.timer.cancel(false); m.timer = null; }
    }

    private User requireUser(String username) {
        if (username == null) throw new NotFoundException(ErrorCode.USER_NOT_FOUND, "Usuario no encontrado");
        return userRepository.findByUsername(username)
            .orElseThrow(() -> new NotFoundException(ErrorCode.USER_NOT_FOUND, "Usuario no encontrado"));
    }

    private boolean areFriends(User a, User b) {
        return friendshipRepository.findBetween(a, b)
            .map(f -> f.getStatus() == Friendship.Status.ACCEPTED)
            .orElse(false);
    }

    private static QuizMode parseMode(String raw) {
        QuizMode mode;
        try {
            mode = QuizMode.valueOf(raw == null ? "" : raw.trim().toUpperCase());
        } catch (Exception e) {
            throw new RuntimeException("Modo de quiz no válido: " + raw);
        }
        if (mode == QuizMode.CLASSIC)
            throw new RuntimeException("El modo clásico no está disponible en partidas en vivo");
        return mode;
    }

    private static int clamp(int v, int lo, int hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    // ── Estado en memoria ───────────────────────────────────────────────────────

    private static final class LiveMatch {
        final long id;
        final QuizMode mode;
        final String scope;
        final Long groupId;
        final String host;
        final int totalRounds;
        final int secondsPerRound;
        final List<QuizSong> pool;
        final List<QuizSong> secrets = new ArrayList<>();
        final Set<String> allowed;
        final Set<String> players = new LinkedHashSet<>();

        volatile String status = "LOBBY";
        Set<String> scoringPlayers;
        final Map<String, Integer> scores = new HashMap<>();
        final Map<String, Integer> correctCounts = new HashMap<>();

        int roundIndex = -1;
        QuizSong secret;
        List<MatchOption> options;
        Map<String, PlayerAnswer> answers = new HashMap<>();
        boolean roundEnded = false;
        long roundStartMs, roundEndsMs;
        ScheduledFuture<?> timer;

        LiveMatch(long id, QuizMode mode, String scope, Long groupId, String host,
                  int totalRounds, int secondsPerRound, List<QuizSong> pool, Set<String> allowed) {
            this.id = id;
            this.mode = mode;
            this.scope = scope;
            this.groupId = groupId;
            this.host = host;
            this.totalRounds = totalRounds;
            this.secondsPerRound = secondsPerRound;
            this.pool = pool;
            this.allowed = allowed;
        }
    }

    private record MatchOption(Long id, String title, String artist) {}

    private static final class PlayerAnswer {
        final long optionId;
        final boolean correct;
        final int delta;
        PlayerAnswer(long optionId, boolean correct, int delta) {
            this.optionId = optionId;
            this.correct = correct;
            this.delta = delta;
        }
    }
}
