package com.example.viber.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.viber.model.Friendship;
import com.example.viber.model.Friendship.Status;
import com.example.viber.model.User;

/**
 * Acceso a la tabla de amistades.
 * Las consultas personalizadas (JPQL) gestionan que la relación puede estar en cualquier
 * dirección: A→B o B→A comparten el mismo registro en la tabla.
 */
@Repository
public interface FriendshipRepository extends JpaRepository<Friendship, Long> {

    // Amigos aceptados (en cualquier dirección)
    @Query("""
        SELECT f FROM Friendship f
        WHERE f.status = :status
          AND (f.requester = :user OR f.addressee = :user)
        """)
    List<Friendship> findAcceptedByUser(
        @Param("user") User user,
        @Param("status") Status status
    );

    // Solicitudes recibidas pendientes
    List<Friendship> findByAddresseeAndStatus(User addressee, Status status);

    // Solicitudes enviadas pendientes
    List<Friendship> findByRequesterAndStatus(User requester, Status status);

    // Buscar relación entre dos usuarios (en cualquier dirección)
    @Query("""
        SELECT f FROM Friendship f
        WHERE (f.requester = :a AND f.addressee = :b)
           OR (f.requester = :b AND f.addressee = :a)
        """)
    Optional<Friendship> findBetween(
        @Param("a") User a,
        @Param("b") User b
    );
}