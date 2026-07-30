package com.example.viber.repository;

import com.example.viber.model.User;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserRepositoryTest {

    @Mock
    private UserRepository userRepository;

    private User buildUser(String username, String email, boolean hidden) {
        User user = new User();
        user.setUsername(username);
        user.setEmail(email);
        user.setProfileHidden(hidden);
        return user;
    }

    @Test
    void findByUsername_existingUser_returnsUser() {
        User alice = buildUser("alice", "alice@test.com", false);
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(alice));

        Optional<User> found = userRepository.findByUsername("alice");

        assertTrue(found.isPresent());
        assertEquals("alice", found.get().getUsername());
    }

    @Test
    void findByUsername_nonExistingUser_returnsEmpty() {
        when(userRepository.findByUsername("nobody")).thenReturn(Optional.empty());

        Optional<User> found = userRepository.findByUsername("nobody");

        assertTrue(found.isEmpty());
    }

    @Test
    void findByEmail_existingEmail_returnsUser() {
        User bob = buildUser("bob", "bob@test.com", false);
        when(userRepository.findByEmail("bob@test.com")).thenReturn(Optional.of(bob));

        Optional<User> found = userRepository.findByEmail("bob@test.com");

        assertTrue(found.isPresent());
        assertEquals("bob", found.get().getUsername());
    }

    @Test
    void findByEmail_nonExistingEmail_returnsEmpty() {
        when(userRepository.findByEmail("ghost@test.com")).thenReturn(Optional.empty());

        Optional<User> found = userRepository.findByEmail("ghost@test.com");

        assertTrue(found.isEmpty());
    }
}
