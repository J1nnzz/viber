package com.example.viber.service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutionException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.FieldValue;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.firestore.SetOptions;

/**
 * Mensajes directos (DM) y chat global via Firestore.
 *
 * Estructura:
 *   direct_messages/{conversationId}/
 *     - participants : [user1, user2]
 *     - lastMessage  : String
 *     - lastSender   : String
 *     - lastTimestamp: Long
 *     messages/{autoId}/
 *       - sender    : String
 *       - text      : String
 *       - timestamp : Long
 *
 *   global_chat/messages/{autoId}/
 *     - sender    : String
 *     - text      : String
 *     - timestamp : Long
 */
@Service
public class FirestoreDirectMessageService {

    private static final Logger log = LoggerFactory.getLogger(FirestoreDirectMessageService.class);
    private static final int    MAX_MESSAGES = 50;

    private final Firestore firestore;

    public FirestoreDirectMessageService(Firestore firestore) {
        this.firestore = firestore;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** ID de conversación reproducible y único para dos usuarios. */
    private static String convId(String u1, String u2) {
        return u1.compareTo(u2) < 0 ? u1 + "_" + u2 : u2 + "_" + u1;
    }

    // ── DMs ───────────────────────────────────────────────────────────────────

    /** Envía un mensaje directo de {@code from} a {@code to}. */
    @Async
    public void sendDM(String from, String to, String text) {
        try {
            String convId   = convId(from, to);
            long   now      = System.currentTimeMillis();

            // Mensaje en la sub-colección
            Map<String, Object> msg = new HashMap<>();
            msg.put("sender",    from);
            msg.put("text",      text);
            msg.put("timestamp", now);

            firestore.collection("direct_messages")
                .document(convId)
                .collection("messages")
                .add(msg)
                .get();

            // Actualizar / crear el documento-raíz con merge para no borrar readAt_* fields
            Map<String, Object> meta = new HashMap<>();
            meta.put("participants",  List.of(from, to));
            meta.put("lastMessage",   text);
            meta.put("lastSender",    from);
            meta.put("lastTimestamp", now);

            firestore.collection("direct_messages")
                .document(convId)
                .set(meta, SetOptions.merge())
                .get();

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error guardando DM entre {} y {}: {}", from, to, e.getMessage());
        }
    }

    /**
     * Persiste un reto de quiz como mensaje del DM (tipo QUIZ_CHALLENGE con la
     * info de la partida). El cliente lo pinta como tarjeta con botón "Unirse".
     */
    @Async
    public void sendChallenge(String from, String to, Long matchId, String mode, int totalRounds) {
        try {
            String convId = convId(from, to);
            long   now    = System.currentTimeMillis();
            String text   = from + " ha lanzado un duelo de quiz";

            Map<String, Object> msg = new HashMap<>();
            msg.put("sender",      from);
            msg.put("text",        text);
            msg.put("timestamp",   now);
            msg.put("type",        "QUIZ_CHALLENGE");
            msg.put("matchId",     matchId);
            msg.put("mode",        mode);
            msg.put("totalRounds", totalRounds);

            firestore.collection("direct_messages")
                .document(convId).collection("messages").add(msg).get();

            Map<String, Object> meta = new HashMap<>();
            meta.put("participants",  List.of(from, to));
            meta.put("lastMessage",   text);
            meta.put("lastSender",    from);
            meta.put("lastTimestamp", now);
            firestore.collection("direct_messages")
                .document(convId).set(meta, SetOptions.merge()).get();

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error guardando reto DM entre {} y {}: {}", from, to, e.getMessage());
        }
    }

    /**
     * Persiste el resultado final de un quiz como mensaje del DM (tipo QUIZ_RESULT,
     * con la clasificación embebida). El cliente lo pinta como tarjeta con la
     * puntuación y un botón para ver la clasificación completa.
     */
    @Async
    public void sendResult(String from, String to, Long matchId, String winner,
                           List<Map<String, Object>> standings) {
        try {
            String convId = convId(from, to);
            long   now    = System.currentTimeMillis();
            String text   = "Quiz terminado — ganó " + winner;

            Map<String, Object> msg = new HashMap<>();
            msg.put("sender",    from);
            msg.put("text",      text);
            msg.put("timestamp", now);
            msg.put("type",      "QUIZ_RESULT");
            msg.put("matchId",   matchId);
            msg.put("winner",    winner);
            msg.put("standings", standings);

            firestore.collection("direct_messages")
                .document(convId).collection("messages").add(msg).get();

            Map<String, Object> meta = new HashMap<>();
            meta.put("participants",  List.of(from, to));
            meta.put("lastMessage",   text);
            meta.put("lastSender",    from);
            meta.put("lastTimestamp", now);
            firestore.collection("direct_messages")
                .document(convId).set(meta, SetOptions.merge()).get();

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error guardando resultado DM entre {} y {}: {}", from, to, e.getMessage());
        }
    }

    /**
     * Devuelve los últimos mensajes entre dos usuarios, orden cronológico.
     * Además:
     *  - Marca readAt_{requester} = now en el documento raíz (el requester ha leído).
     *  - Devuelve otherReadAt = readAt_{other} para que el remitente sepa si sus
     *    mensajes fueron vistos.
     *
     * @param requester  quien hace la petición (abre el chat)
     * @param other      el otro participante
     */
    public Map<String, Object> getDMs(String requester, String other) {
        try {
            String convId = convId(requester, other);
            long   now    = System.currentTimeMillis();

            // Leer documento raíz (readAt del otro) y mensajes en paralelo
            var convRef = firestore.collection("direct_messages").document(convId);

            var snapFuture = convRef
                .collection("messages")
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .limit(MAX_MESSAGES)
                .get();

            var metaFuture = convRef.get();

            QuerySnapshot    snap = snapFuture.get();
            DocumentSnapshot meta = metaFuture.get();

            // set+merge para que funcione aunque el doc todavía no exista
            Map<String, Object> readAtPatch = new HashMap<>();
            readAtPatch.put("readAt_" + requester, now);
            convRef.set(readAtPatch, SetOptions.merge());

            // Leer readAt del otro participante
            long otherReadAt = 0L;
            if (meta.exists()) {
                Number val = (Number) meta.get("readAt_" + other);
                if (val != null) otherReadAt = val.longValue();
            }

            List<Map<String, Object>> messages = new ArrayList<>();
            List<QueryDocumentSnapshot> docs = snap.getDocuments();
            for (int i = docs.size() - 1; i >= 0; i--) {
                messages.add(docs.get(i).getData());
            }

            Map<String, Object> result = new HashMap<>();
            result.put("messages",    messages);
            result.put("otherReadAt", otherReadAt);
            return result;

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error leyendo DMs entre {} y {}: {}", requester, other, e.getMessage());
            Map<String, Object> empty = new HashMap<>();
            empty.put("messages",    List.of());
            empty.put("otherReadAt", 0L);
            return empty;
        } catch (Exception e) {
            log.error("Error inesperado en getDMs entre {} y {}: {}", requester, other, e.getMessage());
            Map<String, Object> empty = new HashMap<>();
            empty.put("messages",    List.of());
            empty.put("otherReadAt", 0L);
            return empty;
        }
    }

    /**
     * Devuelve la lista de conversaciones activas del usuario, ordenadas
     * por último mensaje (más reciente primero).
     */
    public List<Map<String, Object>> getConversations(String username) {
        try {
            // Note: combining whereArrayContains + orderBy requires a composite
            // Firestore index. We skip orderBy here and sort in Java instead.
            QuerySnapshot snap = firestore
                .collection("direct_messages")
                .whereArrayContains("participants", username)
                .limit(30)
                .get()
                .get();

            List<Map<String, Object>> result = new ArrayList<>();
            for (QueryDocumentSnapshot doc : snap.getDocuments()) {
                Map<String, Object> data = new HashMap<>(doc.getData());
                data.put("convId", doc.getId());
                @SuppressWarnings("unchecked")
                List<String> parts = (List<String>) data.get("participants");
                if (parts != null) {
                    String other = parts.stream()
                        .filter(p -> !p.equals(username))
                        .findFirst()
                        .orElse(null);
                    data.put("otherUser", other);
                }
                result.add(data);
            }

            // Sort by lastTimestamp descending (most recent first)
            result.sort((a, b) -> {
                long tsA = a.get("lastTimestamp") instanceof Number n ? n.longValue() : 0L;
                long tsB = b.get("lastTimestamp") instanceof Number n ? n.longValue() : 0L;
                return Long.compare(tsB, tsA);
            });

            return result;

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error leyendo conversaciones de {}: {}", username, e.getMessage());
            return List.of();
        }
    }

    // ── Chat global ───────────────────────────────────────────────────────────

    @Async
    public void sendGlobal(String from, String text) {
        try {
            Map<String, Object> msg = new HashMap<>();
            msg.put("sender",    from);
            msg.put("text",      text);
            msg.put("timestamp", System.currentTimeMillis());

            firestore.collection("global_chat")
                .document("messages")
                .collection("msgs")
                .add(msg)
                .get();

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error guardando mensaje global de {}: {}", from, e.getMessage());
        }
    }

    public List<Map<String, Object>> getGlobalMessages() {
        try {
            QuerySnapshot snap = firestore
                .collection("global_chat")
                .document("messages")
                .collection("msgs")
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .limit(MAX_MESSAGES)
                .get()
                .get();

            List<Map<String, Object>> result = new ArrayList<>();
            List<QueryDocumentSnapshot> docs = snap.getDocuments();
            for (int i = docs.size() - 1; i >= 0; i--) {
                result.add(docs.get(i).getData());
            }
            return result;

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error leyendo chat global: {}", e.getMessage());
            return List.of();
        }
    }
}
