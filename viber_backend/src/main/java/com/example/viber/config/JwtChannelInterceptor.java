package com.example.viber.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.stereotype.Component;

import com.example.viber.utils.JwtUtil;

/**
 * Interceptor que se ejecuta en cada mensaje STOMP entrante.
 *
 * En el frame CONNECT lee el header "Authorization: Bearer <token>",
 * valida el JWT y registra un StompPrincipal en la sesión.
 *
 * Esto permite que convertAndSendToUser() resuelva correctamente
 * el destinatario del mensaje personal de expulsión (/user/queue/kick).
 */
@Component
public class JwtChannelInterceptor implements ChannelInterceptor {

    @Autowired
    private JwtUtil jwtUtil;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor =
            MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);

        if (accessor == null) return message;

        // Solo nos interesa el frame CONNECT — es donde el cliente manda las credenciales
        if (StompCommand.CONNECT.equals(accessor.getCommand())) {
            String authHeader = accessor.getFirstNativeHeader("Authorization");

            if (authHeader != null && authHeader.startsWith("Bearer ")) {
                String token = authHeader.substring(7);
                try {
                    if (jwtUtil.validateToken(token)) {
                        String username = jwtUtil.getUsernameFromToken(token);
                        // Registrar el Principal en la sesión STOMP
                        accessor.setUser(new StompPrincipal(username));
                    }
                } catch (Exception e) {
                    // Token inválido — dejamos pasar sin Principal
                    // El WS sigue funcionando pero los mensajes personales no llegarán
                }
            }
        }

        return message;
    }
}