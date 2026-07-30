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

import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.firestore.SetOptions;

/**
 * Mensajes de grupo en Firestore (gemelo de {@link FirestoreDirectMessageService}
 * para los DM 1-a-1). La membresía y los permisos se validan en {@link GroupService}
 * antes de llamar aquí; este servicio solo persiste y lee.
 *
 * Estructura:
 *   group_messages/{groupId}/
 *     - lastMessage  : String
 *     - lastSender   : String
 *     - lastTimestamp: Long
 *     messages/{autoId}/
 *       - sender    : String   (username, o "system" en mensajes de sistema)
 *       - text      : String
 *       - timestamp : Long
 *       - type      : String   ("USER" | "SYSTEM")
 */
@Service
public class FirestoreGroupMessageService {

    private static final Logger log = LoggerFactory.getLogger(FirestoreGroupMessageService.class);
    private static final int    MAX_MESSAGES = 50;
    private static final String SYSTEM_SENDER = "system";

    private final Firestore firestore;

    public FirestoreGroupMessageService(Firestore firestore) {
        this.firestore = firestore;
    }

    // ── Envío ───────────────────────────────────────────────────────────────────

    /** Mensaje normal de un miembro al grupo. */
    @Async
    public void sendGroupMessage(Long groupId, String sender, String text) {
        persist(groupId, sender, text, "USER");
    }

    /** Mensaje de sistema (altas, expulsiones, resultados de quiz…). */
    @Async
    public void sendSystemMessage(Long groupId, String text) {
        persist(groupId, SYSTEM_SENDER, text, "SYSTEM");
    }

    /** Persiste el resultado final de un quiz como mensaje del grupo (tipo QUIZ_RESULT). */
    @Async
    public void sendResult(Long groupId, long matchId, String winner,
                           java.util.List<Map<String, Object>> standings) {
        try {
            long now = System.currentTimeMillis();
            String text = "Quiz terminado — ganó " + winner;

            Map<String, Object> msg = new HashMap<>();
            msg.put("sender",    "system");
            msg.put("text",      text);
            msg.put("timestamp", now);
            msg.put("type",      "QUIZ_RESULT");
            msg.put("matchId",   matchId);
            msg.put("winner",    winner);
            msg.put("standings", standings);

            firestore.collection("group_messages")
                .document(String.valueOf(groupId))
                .collection("messages").add(msg).get();

            Map<String, Object> meta = new HashMap<>();
            meta.put("lastMessage",   text);
            meta.put("lastSender",    "system");
            meta.put("lastTimestamp", now);
            firestore.collection("group_messages")
                .document(String.valueOf(groupId)).set(meta, SetOptions.merge()).get();

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error guardando resultado en el grupo {}: {}", groupId, e.getMessage());
        }
    }

    /** Persiste un reto de quiz como mensaje del grupo (tipo QUIZ_CHALLENGE). */
    @Async
    public void sendChallenge(Long groupId, String host, Long matchId, String mode, int totalRounds) {
        try {
            long now = System.currentTimeMillis();
            String text = host + " ha lanzado un duelo de quiz";

            Map<String, Object> msg = new HashMap<>();
            msg.put("sender",      host);
            msg.put("text",        text);
            msg.put("timestamp",   now);
            msg.put("type",        "QUIZ_CHALLENGE");
            msg.put("matchId",     matchId);
            msg.put("mode",        mode);
            msg.put("totalRounds", totalRounds);

            firestore.collection("group_messages")
                .document(String.valueOf(groupId))
                .collection("messages").add(msg).get();

            Map<String, Object> meta = new HashMap<>();
            meta.put("lastMessage",   text);
            meta.put("lastSender",    host);
            meta.put("lastTimestamp", now);
            firestore.collection("group_messages")
                .document(String.valueOf(groupId)).set(meta, SetOptions.merge()).get();

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error guardando reto en el grupo {}: {}", groupId, e.getMessage());
        }
    }

    private void persist(Long groupId, String sender, String text, String type) {
        try {
            long now = System.currentTimeMillis();
            String docId = String.valueOf(groupId);

            Map<String, Object> msg = new HashMap<>();
            msg.put("sender",    sender);
            msg.put("text",      text);
            msg.put("timestamp", now);
            msg.put("type",      type);

            firestore.collection("group_messages")
                .document(docId)
                .collection("messages")
                .add(msg)
                .get();

            // Documento raíz con el último mensaje, para la vista previa en la lista
            Map<String, Object> meta = new HashMap<>();
            meta.put("lastMessage",   text);
            meta.put("lastSender",    sender);
            meta.put("lastTimestamp", now);

            firestore.collection("group_messages")
                .document(docId)
                .set(meta, SetOptions.merge())
                .get();

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error guardando mensaje del grupo {}: {}", groupId, e.getMessage());
        }
    }

    // ── Lectura ─────────────────────────────────────────────────────────────────

    /** Últimos mensajes del grupo en orden cronológico (más antiguo primero). */
    public List<Map<String, Object>> getGroupMessages(Long groupId) {
        try {
            QuerySnapshot snap = firestore
                .collection("group_messages")
                .document(String.valueOf(groupId))
                .collection("messages")
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
            log.error("Error leyendo mensajes del grupo {}: {}", groupId, e.getMessage());
            return List.of();
        }
    }

    // ── Borrado ─────────────────────────────────────────────────────────────────

    /** Borra todos los mensajes y el documento raíz de un grupo (al eliminar el grupo). */
    @Async
    public void deleteGroupMessages(Long groupId) {
        try {
            String docId = String.valueOf(groupId);
            var msgs = firestore.collection("group_messages")
                .document(docId)
                .collection("messages")
                .get()
                .get();
            for (QueryDocumentSnapshot doc : msgs.getDocuments()) {
                doc.getReference().delete();
            }
            firestore.collection("group_messages").document(docId).delete();
        } catch (InterruptedException | ExecutionException e) {
            log.error("Error borrando mensajes del grupo {}: {}", groupId, e.getMessage());
        }
    }
}
