package com.example.viber.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.RoomInvitation;
import com.example.viber.model.User;

/**
 * Acceso a la tabla de invitaciones a sala.
 * Controla que no se envíen invitaciones duplicadas a la misma sala para el mismo usuario.
 */
@Repository
public interface RoomInvitationRepository extends JpaRepository<RoomInvitation, Long> {

    // Invitaciones pendientes para un usuario
    List<RoomInvitation> findByReceiverAndStatus(User receiver, String status);

    // Comprobar si ya existe una invitación pendiente de sender → receiver para esa sala
    boolean existsBySenderAndReceiverAndRoomIdAndStatus(
        User sender, User receiver, Long roomId, String status);
}
