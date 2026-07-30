package com.example.viber.service;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;

import com.example.viber.dto.RoomMessage;
import com.example.viber.model.RoomState;

@Service
public class RoomStateService {

    // ConcurrentHashMap → thread-safe para múltiples usuarios simultáneos
    private final Map<Long, RoomState> roomStates = new ConcurrentHashMap<>();

    // @Lazy para evitar dependencia circular (FirestoreQueueService → Firestore → FirebaseConfig)
    private final FirestoreQueueService firestoreQueueService;

    @Autowired
    private UserStatsService userStatsService;

    @Autowired
    private TasteProfileService tasteProfileService;

    @Autowired
    private TrackMetadataService trackMetadataService;

    public RoomStateService(@Lazy FirestoreQueueService firestoreQueueService) {
        this.firestoreQueueService = firestoreQueueService;
    }

    // ── Acceso al estado ──────────────────────────────────────────────────────

    public RoomState getOrCreate(Long roomId) {
        return roomStates.computeIfAbsent(roomId, id -> new RoomState());
    }

    public RoomState getState(Long roomId) {
        return roomStates.get(roomId);
    }

    // ── Inicialización de sala ────────────────────────────────────────────────

    /**
     * Registra al host cuando se crea la sala.
     * Si la sala ya tenía una cola persistida en Firestore (ej. tras reinicio del servidor),
     * la restaura en memoria.
     * Debe llamarse desde RoomService.createRoom() justo después de persistir la sala.
     */
    public void initRoom(Long roomId, String hostUsername, Integer maxParticipants) {
        RoomState state = getOrCreate(roomId);
        state.setHost(hostUsername);
        state.setMaxParticipants(maxParticipants);

        // Restaurar cola persistida si existe (lista vacía si es sala nueva)
        List<RoomState.QueueItem> savedQueue = firestoreQueueService.loadQueue(roomId);
        if (!savedQueue.isEmpty()) {
            state.getQueue().addAll(savedQueue);
        }
    }

    /** true si la sala está llena para ese usuario (el host siempre puede entrar). */
    public boolean isRoomFull(Long roomId, String username) {
        RoomState state = roomStates.get(roomId);
        return state != null && state.isFull(username);
    }

    // ── Validación de permisos ────────────────────────────────────────────────

    /**
     * Devuelve true si el mensaje debe ser rechazado por falta de permisos.
     * El WebSocketController llama esto antes de applyMessage().
     */
    public boolean isUnauthorized(Long roomId, RoomMessage message) {
        RoomState state = getOrCreate(roomId);
        String sender = message.getSenderUsername();

        if (sender == null) return true;

        // Usuario expulsado → rechazar todo
        if (state.isKicked(sender)) return true;

        switch (message.getType()) {
            // Solo el host controla la reproducción
            case PLAY, PAUSE, SEEK -> {
                return !state.canControlPlayback(sender);
            }
            // Host y DJ gestionan la cola
            case NEXT, PREV, QUEUE_ADD, QUEUE_REMOVE, QUEUE_MOVE -> {
                return !state.canManageQueue(sender);
            }
            // Solo el host puede moderar y cambiar roles
            case ROLE_CHANGE, USER_KICKED, USER_UNKICKED, USER_MUTED, USER_UNMUTED -> {
                return !state.isHost(sender);
            }
            // Chat: usuarios silenciados no pueden enviar
            case CHAT -> {
                return state.isMuted(sender);
            }
            // USER_JOINED, USER_LEFT → siempre permitido
            default -> { return false; }
        }
    }

    // ── Aplicar mensaje al estado ─────────────────────────────────────────────

    public void applyMessage(Long roomId, RoomMessage message) {
        RoomState state = getOrCreate(roomId);
        String previousVideoId = state.getCurrentVideoId();

        switch (message.getType()) {

            // ── Reproducción ─────────────────────────────────────────────────
            case PLAY -> {
                if (state.getCurrentVideoId() != null
                        && message.getVideoId() != null
                        && !message.getVideoId().equals(state.getCurrentVideoId())) {
                    RoomState.QueueItem histItem = new RoomState.QueueItem();
                    histItem.setVideoId(state.getCurrentVideoId());
                    histItem.setTitle(state.getCurrentVideoTitle());
                    histItem.setThumbnail(state.getCurrentVideoThumbnail());
                    histItem.setChannelTitle(state.getCurrentVideoChannel());
                    state.getHistory().add(histItem);
                }
                state.setPlaying(true);
                // Los mensajes PLAY de "reanudar" (pausa→play) solo llevan videoId+position,
                // sin metadatos. No pisar título/miniatura/canal de la canción actual con null.
                if (message.getVideoId() != null) {
                    state.setCurrentVideoId(message.getVideoId());
                }
                if (message.getVideoTitle() != null) {
                    state.setCurrentVideoTitle(message.getVideoTitle());
                }
                if (message.getVideoThumbnail() != null) {
                    state.setCurrentVideoThumbnail(message.getVideoThumbnail());
                }
                if (message.getVideoChannel() != null) {
                    state.setCurrentVideoChannel(message.getVideoChannel());
                }
                state.setCurrentPosition(message.getPosition() != null ? message.getPosition() : 0.0);
                state.setLastUpdateTimestamp(message.getServerTimestamp());
            }

            case PAUSE -> {
                state.setPlaying(false);
                state.setCurrentPosition(
                    message.getPosition() != null ? message.getPosition() : state.getCurrentPosition());
                state.setLastUpdateTimestamp(message.getServerTimestamp());
            }

            case SEEK -> {
                state.setCurrentPosition(message.getPosition());
                state.setLastUpdateTimestamp(message.getServerTimestamp());
            }

            // ── Cola ─────────────────────────────────────────────────────────
            case QUEUE_ADD -> {
                RoomState.QueueItem item = new RoomState.QueueItem();
                item.setVideoId(message.getVideoId());
                item.setTitle(message.getVideoTitle());
                item.setThumbnail(message.getVideoThumbnail());
                item.setAddedBy(message.getSenderUsername());
                item.setChannelTitle(message.getVideoChannel());
                state.getQueue().add(item);
                userStatsService.recordSongAdded(message.getSenderUsername());

                // Si no hay nada sonando arrancamos automáticamente
                if (state.getCurrentVideoId() == null && state.getQueue().size() == 1) {
                    RoomState.QueueItem first = state.getQueue().remove(0);
                    state.setCurrentVideoId(first.getVideoId());
                    state.setCurrentVideoTitle(first.getTitle());
                    state.setCurrentVideoThumbnail(first.getThumbnail());
                    state.setCurrentVideoChannel(first.getChannelTitle());
                    state.setCurrentPosition(0.0);
                    state.setPlaying(true);
                    state.setLastUpdateTimestamp(message.getServerTimestamp());
                    message.setType(RoomMessage.Type.PLAY);
                }

                // Snapshot async de la cola tras el cambio
                firestoreQueueService.snapshotQueue(roomId, state.getQueue());
            }

            case QUEUE_REMOVE -> {
                if (message.getQueueIndex() != null) {
                    int idx = message.getQueueIndex();
                    if (idx >= 0 && idx < state.getQueue().size()) {
                        state.getQueue().remove(idx);
                    }
                }
                firestoreQueueService.snapshotQueue(roomId, state.getQueue());
            }

            case QUEUE_MOVE -> {
                Integer from = message.getQueueIndex();
                Integer to   = message.getTargetIndex();
                var q = state.getQueue();
                if (from != null && to != null
                        && from >= 0 && from < q.size()
                        && to   >= 0 && to   < q.size()
                        && !from.equals(to)) {
                    var moved = q.remove((int) from);
                    q.add(to, moved);
                }
                firestoreQueueService.snapshotQueue(roomId, state.getQueue());
            }

            case NEXT -> {
                if (!state.getQueue().isEmpty()) {
                    if (state.getCurrentVideoId() != null) {
                        RoomState.QueueItem histItem = new RoomState.QueueItem();
                        histItem.setVideoId(state.getCurrentVideoId());
                        histItem.setTitle(state.getCurrentVideoTitle());
                        histItem.setThumbnail(state.getCurrentVideoThumbnail());
                        histItem.setChannelTitle(state.getCurrentVideoChannel());
                        state.getHistory().add(histItem);
                    }
                    RoomState.QueueItem next = state.getQueue().remove(0);
                    state.setCurrentVideoId(next.getVideoId());
                    state.setCurrentVideoTitle(next.getTitle());
                    state.setCurrentVideoThumbnail(next.getThumbnail());
                    state.setCurrentVideoChannel(next.getChannelTitle());
                    state.setCurrentPosition(0.0);
                    state.setPlaying(true);
                    state.setLastUpdateTimestamp(message.getServerTimestamp());
                }
                firestoreQueueService.snapshotQueue(roomId, state.getQueue());
            }

            case PREV -> {
                if (!state.getHistory().isEmpty()) {
                    if (state.getCurrentVideoId() != null) {
                        RoomState.QueueItem current = new RoomState.QueueItem();
                        current.setVideoId(state.getCurrentVideoId());
                        current.setTitle(state.getCurrentVideoTitle());
                        current.setThumbnail(state.getCurrentVideoThumbnail());
                        current.setChannelTitle(state.getCurrentVideoChannel());
                        state.getQueue().add(0, current);
                    }
                    RoomState.QueueItem prev =
                        state.getHistory().remove(state.getHistory().size() - 1);
                    state.setCurrentVideoId(prev.getVideoId());
                    state.setCurrentVideoTitle(prev.getTitle());
                    state.setCurrentVideoThumbnail(prev.getThumbnail());
                    state.setCurrentVideoChannel(prev.getChannelTitle());
                    state.setCurrentPosition(0.0);
                    state.setPlaying(true);
                    state.setLastUpdateTimestamp(message.getServerTimestamp());
                }
                firestoreQueueService.snapshotQueue(roomId, state.getQueue());
            }

            // ── Roles ────────────────────────────────────────────────────────
            case ROLE_CHANGE -> {
                String target  = message.getTargetUsername();
                String newRole = message.getRole();
                if (target != null && (newRole != null)) {
                    if ("DJ".equals(newRole) || "LISTENER".equals(newRole)) {
                        state.getUserRoles().put(target, newRole);
                    }
                }
            }

            // ── Moderación ───────────────────────────────────────────────────
            case USER_KICKED -> {
                String target = message.getTargetUsername();
                if (target != null) {
                    state.getKickedUsers().add(target);
                    state.getUserRoles().remove(target);
                }
            }

            case USER_UNKICKED -> {
                String target = message.getTargetUsername();
                if (target != null) {
                    // Levanta el ban: el usuario puede volver a unirse
                    state.getKickedUsers().remove(target);
                }
            }

            case USER_MUTED -> {
                String target = message.getTargetUsername();
                if (target != null) state.getMutedUsers().add(target);
            }

            case USER_UNMUTED -> {
                String target = message.getTargetUsername();
                if (target != null) state.getMutedUsers().remove(target);
            }

            // ── Usuarios entrando/saliendo ────────────────────────────────────
            case USER_JOINED -> {
                String sender = message.getSenderUsername();
                if (sender != null) {
                    // Si la sala estaba vacía y reproduciendo, avanzar la posición virtual.
                    // Cuando el cliente reciba el /state con esta posición actualizada,
                    // el player hará seek allí; si supera la duración del vídeo, el
                    // onEnded del YouTubePlayer disparará NEXT automáticamente.
                    if (state.getLastEmptyTimestamp() != null && state.isPlaying()) {
                        double elapsed = (System.currentTimeMillis() - state.getLastEmptyTimestamp()) / 1000.0;
                        state.setCurrentPosition(state.getCurrentPosition() + elapsed);
                        state.setLastUpdateTimestamp(System.currentTimeMillis());
                    }
                    state.setLastEmptyTimestamp(null);
                    state.addUser(sender);
                }
            }

            case USER_LEFT -> {
                String sender = message.getSenderUsername();
                if (sender != null) state.removeUser(sender);
            }

            // CHAT no modifica el estado del reproductor ni de roles
            default -> { }
        }

        // Si la canción actual cambió, registrar reproducción para los oyentes online
        if (state.getCurrentVideoId() != null && !state.getCurrentVideoId().equals(previousVideoId)) {
            String videoId = state.getCurrentVideoId();
            String artist  = state.getCurrentVideoChannel();

            // Tally acumulado de artistas (estadísticas de perfil, ya existente)
            userStatsService.recordSongPlayed(state.getOnlineUsers(), artist);

            // Eventos con timestamp → recencia (gusto del usuario + huella de la sala)
            tasteProfileService.recordPlay(state.getOnlineUsers(), roomId, videoId, artist);

            // Enriquecer metadatos en segundo plano (Deezer), una sola vez por videoId.
            // No bloquea el broadcast: corre en el pool de @Async.
            trackMetadataService.enrichAsync(videoId, state.getCurrentVideoTitle(), artist);
        }
    }

    // ── Limpieza ──────────────────────────────────────────────────────────────

    /** Limpia el estado en memoria cuando la sala se cierra. */
    public void clearState(Long roomId) {
        roomStates.remove(roomId);
    }
}