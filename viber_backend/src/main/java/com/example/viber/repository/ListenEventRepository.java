package com.example.viber.repository;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.ListenEvent;
import com.example.viber.model.User;

/**
 * Acceso a los eventos de escucha con timestamp.
 *
 * Las dos consultas por ventana ({@code ...PlayedAtAfter}) son la base del
 * cálculo de recencia: solo traen lo de los últimos N días (lo más viejo ya
 * pesa ~0 con el decay) y el resto del trabajo se hace en memoria.
 */
@Repository
public interface ListenEventRepository extends JpaRepository<ListenEvent, Long> {

    /** Eventos de un usuario desde un instante (gusto del usuario). */
    List<ListenEvent> findByUserAndPlayedAtAfter(User user, LocalDateTime since);

    /** Eventos de una sala desde un instante (huella de la sala). */
    List<ListenEvent> findByRoomIdAndPlayedAtAfter(Long roomId, LocalDateTime since);
}
