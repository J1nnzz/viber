package com.example.viber.controller;

import java.security.Principal;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Controller;

import com.example.viber.service.QuizMatchService;

/**
 * Eventos en vivo de una partida de quiz sobre STOMP.
 *
 * El jugador SIEMPRE se toma del {@link Principal} (JWT validado en el CONNECT por
 * {@code JwtChannelInterceptor}), nunca de datos del cliente.
 *
 * <ul>
 *   <li>cliente → {@code /app/quizmatch.{id}.join}   — entrar en la sala de espera</li>
 *   <li>cliente → {@code /app/quizmatch.{id}.leave}  — salir de la sala de espera</li>
 *   <li>cliente → {@code /app/quizmatch.{id}.start}  — (anfitrión) empezar la partida</li>
 *   <li>cliente → {@code /app/quizmatch.{id}.answer} — responder · payload {@code {optionId}}</li>
 * </ul>
 * Las difusiones (lobby, pregunta, revelación, final) salen por {@code /topic/quizmatch.{id}}.
 */
@Controller
public class QuizMatchWebSocketController {

    @Autowired private QuizMatchService quizMatchService;

    @MessageMapping("/quizmatch.{id}.join")
    public void join(@DestinationVariable Long id, Principal principal) {
        if (principal != null) quizMatchService.join(id, principal.getName());
    }

    @MessageMapping("/quizmatch.{id}.leave")
    public void leave(@DestinationVariable Long id, Principal principal) {
        if (principal != null) quizMatchService.leaveLobby(id, principal.getName());
    }

    @MessageMapping("/quizmatch.{id}.start")
    public void start(@DestinationVariable Long id, Principal principal) {
        if (principal != null) quizMatchService.start(id, principal.getName());
    }

    @MessageMapping("/quizmatch.{id}.answer")
    public void answer(@DestinationVariable Long id,
                       @Payload Map<String, Object> body,
                       Principal principal) {
        if (principal == null) return;
        Object opt = body.get("optionId");
        Long optionId = (opt instanceof Number n) ? n.longValue() : null;
        quizMatchService.answer(id, principal.getName(), optionId);
    }
}
