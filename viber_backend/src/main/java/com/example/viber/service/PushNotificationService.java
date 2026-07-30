package com.example.viber.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import com.example.viber.model.DeviceToken;
import com.example.viber.model.User;
import com.example.viber.repository.DeviceTokenRepository;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.SendResponse;

/**
 * Envío de notificaciones push a los dispositivos de un usuario mediante
 * Firebase Cloud Messaging. Reutiliza el {@code FirebaseApp} ya inicializado en
 * {@link com.example.viber.config.FirebaseConfig} (el mismo que usa Firestore).
 *
 * <p>El envío es {@code @Async} para no bloquear la respuesta HTTP. Si Firebase
 * no estuviera disponible, se registra un aviso y la app sigue funcionando con
 * el sistema de polling de siempre.</p>
 */
@Service
public class PushNotificationService {

    private static final Logger log = LoggerFactory.getLogger(PushNotificationService.class);

    private final DeviceTokenRepository tokenRepository;

    public PushNotificationService(DeviceTokenRepository tokenRepository) {
        this.tokenRepository = tokenRepository;
    }

    /**
     * Envía una notificación a todos los dispositivos registrados de [user].
     * Los tokens inválidos/caducados se eliminan automáticamente.
     *
     * @param data pares clave-valor opcionales para enrutar la notificación en
     *             el cliente (p. ej. {@code {"type":"room_invite","roomId":"5"}}).
     */
    @Async
    public void sendToUser(User user, String title, String body, Map<String, String> data) {
        if (user == null) return;

        List<DeviceToken> tokens = tokenRepository.findByUser(user);
        if (tokens.isEmpty()) return;

        final FirebaseMessaging fm;
        try {
            fm = FirebaseMessaging.getInstance();
        } catch (Exception e) {
            log.warn("FCM no disponible, se omite el push: {}", e.getMessage());
            return;
        }

        List<Message> messages = new ArrayList<>(tokens.size());
        for (DeviceToken dt : tokens) {
            Message.Builder builder = Message.builder()
                .setToken(dt.getToken())
                .setNotification(Notification.builder()
                    .setTitle(title)
                    .setBody(body)
                    .build())
                .setAndroidConfig(AndroidConfig.builder()
                    .setPriority(AndroidConfig.Priority.HIGH)
                    .build());
            if (data != null) builder.putAllData(data);
            messages.add(builder.build());
        }

        try {
            BatchResponse response = fm.sendEach(messages);
            List<SendResponse> responses = response.getResponses();
            for (int i = 0; i < responses.size(); i++) {
                SendResponse r = responses.get(i);
                if (r.isSuccessful()) continue;

                MessagingErrorCode code = (r.getException() != null)
                    ? r.getException().getMessagingErrorCode() : null;
                // Token caducado o inválido → limpiarlo para no reintentar.
                if (code == MessagingErrorCode.UNREGISTERED
                        || code == MessagingErrorCode.INVALID_ARGUMENT) {
                    tokenRepository.delete(tokens.get(i));
                }
            }
        } catch (Exception e) {
            log.warn("Error enviando push a {}: {}", user.getUsername(), e.getMessage());
        }
    }
}
