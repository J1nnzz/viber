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

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;

/**
 * Persiste y recupera mensajes de chat en Firestore.
 *
 * Estructura Firestore:
 *   rooms/{roomId}/messages/{autoId}
 *     - sender    : String
 *     - text      : String
 *     - timestamp : Long (epoch ms)
 *
 * El método saveMessage es @Async — no bloquea el hilo del WebSocket.
 * La latencia de escritura en Firestore no afecta la sincronización en tiempo real.
 */
@Service
public class FirestoreChatService {

    private static final Logger log = LoggerFactory.getLogger(FirestoreChatService.class);
    private static final int MAX_HISTORY = 50;

    private final Firestore firestore;

    public FirestoreChatService(Firestore firestore) {
        this.firestore = firestore;
    }

    // ── Guardar mensaje (async, no bloquea WebSocket) ─────────────────────────

    @Async
    public void saveMessage(Long roomId, String sender, String text, Long timestamp) {
        try {
            Map<String, Object> data = new HashMap<>();
            data.put("sender",    sender);
            data.put("text",      text);
            data.put("timestamp", timestamp);

            // Firestore genera el ID automáticamente con .add()
            DocumentReference ref = firestore
                .collection("rooms")
                .document(String.valueOf(roomId))
                .collection("messages")
                .document();

            ref.set(data).get(); // .get() dentro del hilo async — no bloquea el WebSocket
        } catch (InterruptedException | ExecutionException e) {
            // No propagamos — un fallo de persistencia no debe romper el chat en vivo
            log.error("Error guardando mensaje en Firestore para sala {}: {}", roomId, e.getMessage());
        }
    }

    // ── Cargar historial al entrar a la sala ──────────────────────────────────

    /**
     * Devuelve los últimos MAX_HISTORY mensajes ordenados por timestamp ascendente.
     * Llamado desde RoomController.getRoomState() para incluirlos en la respuesta inicial.
     */
    public List<Map<String, Object>> loadHistory(Long roomId) {
        try {
            ApiFuture<QuerySnapshot> future = firestore
                .collection("rooms")
                .document(String.valueOf(roomId))
                .collection("messages")
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .limit(MAX_HISTORY)
                .get();

            List<QueryDocumentSnapshot> docs = future.get().getDocuments();
            List<Map<String, Object>> result = new ArrayList<>();

            // Invertimos para devolver en orden cronológico (más antiguo primero)
            for (int i = docs.size() - 1; i >= 0; i--) {
                result.add(docs.get(i).getData());
            }
            return result;

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error cargando historial de sala {}: {}", roomId, e.getMessage());
            return List.of(); // Fallo silencioso — el usuario entra sin historial
        }
    }

    // ── Limpiar mensajes al cerrar sala ───────────────────────────────────────

    /**
     * Elimina todos los mensajes de la sala.
     * Llamado desde RoomService.closeRoom() para no acumular datos huérfanos.
     */
    @Async
    public void clearMessages(Long roomId) {
        try {
            QuerySnapshot snapshot = firestore
                .collection("rooms")
                .document(String.valueOf(roomId))
                .collection("messages")
                .get()
                .get();

            for (QueryDocumentSnapshot doc : snapshot.getDocuments()) {
                doc.getReference().delete();
            }
        } catch (InterruptedException | ExecutionException e) {
            log.error("Error limpiando mensajes de sala {}: {}", roomId, e.getMessage());
        }
    }
}