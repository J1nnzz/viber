package com.example.viber.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

/**
 * Configura el broker STOMP sobre SockJS.
 *
 * Canales de publicación:
 *  - /topic/room.{roomId} — broadcast de todos los eventos de sala
 *  - /topic/rooms         — eventos de creación/edición/cierre de salas públicas
 *  - /user/queue/kick     — notificación personal de expulsión
 *  - /user/queue/full     — notificación personal de sala llena
 *
 * Los clientes envían mensajes a /app/room.{roomId}.control.
 */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Autowired
    private JwtChannelInterceptor jwtChannelInterceptor;

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // Broker para mensajes broadcast y personales
        config.enableSimpleBroker("/topic", "/queue");
        // Prefijo para mensajes que los clientes envían al servidor
        config.setApplicationDestinationPrefixes("/app");
        // Prefijo para mensajes personales — resuelve /user/{username}/queue/kick
        config.setUserDestinationPrefix("/user");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*")
                .withSockJS();
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        // Registrar el interceptor JWT — Spring necesita conocer el Principal
        // de cada sesión para enrutar mensajes personales con convertAndSendToUser()
        registration.interceptors(jwtChannelInterceptor);
    }
}