package com.example.viber.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.ChatGroup;

/** Acceso a la tabla de grupos de chat. */
@Repository
public interface ChatGroupRepository extends JpaRepository<ChatGroup, Long> {
}
