package com.example.viber.model;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class UserTest {

    private User buildUser(User.AuthProvider provider, String password) {
        User user = new User();
        user.setUsername("testuser");
        user.setEmail("test@test.com");
        user.setAuthProvider(provider);
        user.setPassword(password);
        return user;
    }

    @Test
    void hasPassword_withPassword_returnsTrue() {
        assertTrue(buildUser(User.AuthProvider.LOCAL, "secret123").hasPassword());
    }

    @Test
    void hasPassword_nullPassword_returnsFalse() {
        assertFalse(buildUser(User.AuthProvider.LOCAL, null).hasPassword());
    }

    @Test
    void hasPassword_blankPassword_returnsFalse() {
        assertFalse(buildUser(User.AuthProvider.LOCAL, "   ").hasPassword());
    }

    @Test
    void canLoginWithGoogle_googleProvider_returnsTrue() {
        assertTrue(buildUser(User.AuthProvider.GOOGLE, null).canLoginWithGoogle());
    }

    @Test
    void canLoginWithGoogle_bothProvider_returnsTrue() {
        assertTrue(buildUser(User.AuthProvider.BOTH, "pass").canLoginWithGoogle());
    }

    @Test
    void canLoginWithGoogle_localProvider_returnsFalse() {
        assertFalse(buildUser(User.AuthProvider.LOCAL, "pass").canLoginWithGoogle());
    }

    @Test
    void canLoginWithPassword_localWithPassword_returnsTrue() {
        assertTrue(buildUser(User.AuthProvider.LOCAL, "secret123").canLoginWithPassword());
    }

    @Test
    void canLoginWithPassword_googleWithoutPassword_returnsFalse() {
        assertFalse(buildUser(User.AuthProvider.GOOGLE, null).canLoginWithPassword());
    }

    @Test
    void canLoginWithPassword_bothWithPassword_returnsTrue() {
        assertTrue(buildUser(User.AuthProvider.BOTH, "secret123").canLoginWithPassword());
    }
}
