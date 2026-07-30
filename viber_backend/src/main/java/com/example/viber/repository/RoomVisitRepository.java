package com.example.viber.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.Room;
import com.example.viber.model.RoomVisit;
import com.example.viber.model.User;

/**
 * Acceso a la tabla de visitas a salas (para "salas unidas" y "géneros más escuchados").
 */
@Repository
public interface RoomVisitRepository extends JpaRepository<RoomVisit, Long> {
    List<RoomVisit> findByUser(User user);
    boolean existsByUserAndRoom(User user, Room room);
    long countByUser(User user);
}
