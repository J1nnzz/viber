package com.example.viber.config;

import java.security.Principal;

/**
 * Principal mínimo para sesiones WebSocket/STOMP.
 * Spring usa este objeto para resolver el destinatario en
 * messagingTemplate.convertAndSendToUser(username, destination, payload).
 */
public class StompPrincipal implements Principal {

    private final String name;

    public StompPrincipal(String name) {
        this.name = name;
    }

    @Override
    public String getName() {
        return name;
    }
}