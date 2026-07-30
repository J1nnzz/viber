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

import com.example.viber.model.RoomState;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;

/**
 * Persiste y recupera la cola de canciones en Firestore.
 *
 * Estructura Firestore:
 *   rooms/{roomId}/queue/{index}
 *     - videoId      : String
 *     - title        : String
 *     - thumbnail    : String
 *     - addedBy      : String
 *     - channelTitle : String  (canal/artista — alimenta las stats de artistas del perfil)
 *
 * La cola en Firestore es un SNAPSHOT del estado en memoria de Spring Boot.
 * Spring sigue siendo la fuente de verdad — Firestore solo sirve para
 * restaurar la cola si el servidor se reinicia.
 *
 * snapshotQueue es @Async — no bloquea el hilo del WebSocket.
 */
@Service
public class FirestoreQueueService {

    private static final Logger log = LoggerFactory.getLogger(FirestoreQueueService.class);

    private final Firestore firestore;

    public FirestoreQueueService(Firestore firestore) {
        this.firestore = firestore;
    }

    // ── Guardar snapshot completo de la cola ──────────────────────────────────

    /**
     * Reemplaza toda la subcolección queue con el estado actual.
     * Se llama en background después de cada QUEUE_ADD, QUEUE_REMOVE, NEXT, PREV.
     */
    @Async
    public void snapshotQueue(Long roomId, List<RoomState.QueueItem> queue) {
        try {
            // 1. Borrar documentos existentes
            clearQueueSync(roomId);

            // 2. Escribir la cola actual con índice como ID de documento
            for (int i = 0; i < queue.size(); i++) {
                RoomState.QueueItem item = queue.get(i);

                Map<String, Object> data = new HashMap<>();
                data.put("videoId",      item.getVideoId());
                data.put("title",        item.getTitle());
                data.put("thumbnail",    item.getThumbnail());
                data.put("addedBy",      item.getAddedBy());
                data.put("channelTitle", item.getChannelTitle()); // canal/artista — necesario para las stats
                data.put("index",        i); // Para ordenar al recuperar

                firestore
                    .collection("rooms")
                    .document(String.valueOf(roomId))
                    .collection("queue")
                    .document(String.valueOf(i))
                    .set(data)
                    .get();
            }
        } catch (InterruptedException | ExecutionException e) {
            log.error("Error guardando cola en Firestore para sala {}: {}", roomId, e.getMessage());
        }
    }

    // ── Cargar cola al restaurar sala ─────────────────────────────────────────

    /**
     * Recupera la cola persistida en Firestore ordenada por índice.
     * Llamado desde RoomStateService.initRoom() si la sala ya existía.
     */
    public List<RoomState.QueueItem> loadQueue(Long roomId) {
        try {
            QuerySnapshot snapshot = firestore
                .collection("rooms")
                .document(String.valueOf(roomId))
                .collection("queue")
                .orderBy("index")
                .get()
                .get();

            List<RoomState.QueueItem> result = new ArrayList<>();
            for (QueryDocumentSnapshot doc : snapshot.getDocuments()) {
                Map<String, Object> data = doc.getData();

                RoomState.QueueItem item = new RoomState.QueueItem();
                item.setVideoId(     (String) data.get("videoId"));
                item.setTitle(       (String) data.get("title"));
                item.setThumbnail(   (String) data.get("thumbnail"));
                item.setAddedBy(     (String) data.get("addedBy"));
                item.setChannelTitle((String) data.get("channelTitle")); // restaura el canal/artista para las stats
                result.add(item);
            }
            return result;

        } catch (InterruptedException | ExecutionException e) {
            log.error("Error cargando cola de sala {}: {}", roomId, e.getMessage());
            return List.of();
        }
    }

    // ── Limpiar cola al cerrar sala ───────────────────────────────────────────

    @Async
    public void clearQueue(Long roomId) {
        try {
            clearQueueSync(roomId);
        } catch (InterruptedException | ExecutionException e) {
            log.error("Error limpiando cola de sala {}: {}", roomId, e.getMessage());
        }
    }

    // ── Privado ───────────────────────────────────────────────────────────────

    private void clearQueueSync(Long roomId) throws InterruptedException, ExecutionException {
        QuerySnapshot existing = firestore
            .collection("rooms")
            .document(String.valueOf(roomId))
            .collection("queue")
            .get()
            .get();

        for (QueryDocumentSnapshot doc : existing.getDocuments()) {
            doc.getReference().delete().get();
        }
    }
}