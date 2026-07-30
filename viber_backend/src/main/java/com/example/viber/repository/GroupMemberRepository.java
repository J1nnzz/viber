package com.example.viber.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.ChatGroup;
import com.example.viber.model.GroupMember;
import com.example.viber.model.User;

/**
 * Acceso a las membresías de grupo.
 * El par (group, user) es único, por eso {@link #findByGroupAndUser} devuelve un Optional.
 */
@Repository
public interface GroupMemberRepository extends JpaRepository<GroupMember, Long> {

    // Grupos a los que pertenece un usuario (para listar "mis grupos")
    List<GroupMember> findByUser(User user);

    // Miembros de un grupo
    List<GroupMember> findByGroup(ChatGroup group);

    // Membresía concreta de un usuario en un grupo (null si no es miembro)
    Optional<GroupMember> findByGroupAndUser(ChatGroup group, User user);

    // Nº de miembros del grupo
    long countByGroup(ChatGroup group);

    boolean existsByGroupAndUser(ChatGroup group, User user);
}
