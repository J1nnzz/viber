package com.example.viber.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.Room;
import com.example.viber.model.User;

/**
 * Acceso a la tabla de salas.
 * Los métodos distinguen entre listados públicos (excluyen flagged) y uso interno
 * del admin (incluyen todas). La búsqueda por código solo devuelve salas activas.
 */
@Repository
public interface RoomRepository extends JpaRepository<Room, Long> {

    // Todas las salas públicas activas (excluye las marcadas con incidencia)
    List<Room> findByPrivacyAndActiveTrueAndFlaggedFalse(String privacy);

    // Todas las salas públicas activas (incluye flagged — solo para uso interno)
    List<Room> findByPrivacyAndActiveTrue(String privacy);

    // Salas creadas por un usuario
    List<Room> findByHostIdAndActiveTrue(Long hostId);

    // Salas activas de un usuario por username (incluye privadas)
    List<Room> findByHost_UsernameAndActiveTrue(String username);

    // Buscar sala privada por código
    Optional<Room> findByAccessCodeAndActiveTrue(String accessCode);

    // Salas permanentes activas con auto-DJ encendido (las que rellena el scheduler)
    List<Room> findByAutoDjTrueAndActiveTrue();

    // Nº total de salas creadas por un usuario (activas o cerradas) — estadística "salas creadas"
    long countByHost(User host);

    // Todas las salas creadas por un usuario (activas o cerradas) — para "géneros más escuchados"
    List<Room> findByHost(User host);
}