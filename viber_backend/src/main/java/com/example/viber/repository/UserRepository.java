package com.example.viber.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.viber.model.User;

/**
 * Acceso a la tabla de usuarios.
 * La búsqueda {@code searchByUsernameOrDisplayName} filtra usuarios con perfil oculto
 * y aplica paginación para limitar los resultados a 10 por consulta.
 */
@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
    Optional<User> findByEmail(String email);
    Optional<User> findByGoogleId(String googleId);

    @Query("SELECT u FROM User u WHERE " +
           "u.profileHidden = false AND (" +
           "LOWER(u.username) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(u.displayName) LIKE LOWER(CONCAT('%', :q, '%')))")
    List<User> searchByUsernameOrDisplayName(@Param("q") String q, Pageable pageable);
}