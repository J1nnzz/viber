package com.example.viber.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.viber.model.DeviceToken;
import com.example.viber.model.User;

/**
 * Acceso a los tokens de dispositivo para notificaciones push (FCM).
 */
@Repository
public interface DeviceTokenRepository extends JpaRepository<DeviceToken, Long> {

    Optional<DeviceToken> findByToken(String token);

    List<DeviceToken> findByUser(User user);
}
