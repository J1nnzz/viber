package com.example.viber.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.ChatGroup;
import com.example.viber.model.GroupInvitation;
import com.example.viber.model.User;

/** Acceso a las invitaciones de grupo. */
@Repository
public interface GroupInvitationRepository extends JpaRepository<GroupInvitation, Long> {

    // Invitaciones pendientes que ha recibido un usuario (para la campana)
    List<GroupInvitation> findByReceiverAndStatus(User receiver, String status);

    // Evitar invitaciones duplicadas pendientes al mismo grupo
    boolean existsByGroupAndReceiverAndStatus(ChatGroup group, User receiver, String status);

    // Limpiar invitaciones pendientes al borrar un grupo
    List<GroupInvitation> findByGroup(ChatGroup group);
}
