package com.example.viber.repository;

import com.example.viber.model.Room;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RoomRepositoryTest {

    @Mock
    private RoomRepository roomRepository;

    private Room buildRoom(String name, String privacy, boolean active, boolean flagged) {
        Room room = new Room();
        room.setName(name);
        room.setPrivacy(privacy);
        room.setActive(active);
        room.setFlagged(flagged);
        return room;
    }

    @Test
    void findByPrivacyAndActiveTrueAndFlaggedFalse_returnsMatchingRooms() {
        Room visible = buildRoom("Visible", "PUBLIC", true, false);
        when(roomRepository.findByPrivacyAndActiveTrueAndFlaggedFalse("PUBLIC"))
            .thenReturn(List.of(visible));

        List<Room> result = roomRepository.findByPrivacyAndActiveTrueAndFlaggedFalse("PUBLIC");

        assertEquals(1, result.size());
        assertEquals("Visible", result.get(0).getName());
    }

    @Test
    void findByPrivacyAndActiveTrueAndFlaggedFalse_noRooms_returnsEmpty() {
        when(roomRepository.findByPrivacyAndActiveTrueAndFlaggedFalse("PUBLIC"))
            .thenReturn(List.of());

        List<Room> result = roomRepository.findByPrivacyAndActiveTrueAndFlaggedFalse("PUBLIC");

        assertTrue(result.isEmpty());
    }

    @Test
    void findByAccessCodeAndActiveTrue_validCode_returnsRoom() {
        Room room = buildRoom("Private Room", "PRIVATE", true, false);
        room.setAccessCode("ABC123");
        when(roomRepository.findByAccessCodeAndActiveTrue("ABC123")).thenReturn(Optional.of(room));

        Optional<Room> found = roomRepository.findByAccessCodeAndActiveTrue("ABC123");

        assertTrue(found.isPresent());
        assertEquals("ABC123", found.get().getAccessCode());
    }

    @Test
    void findByAccessCodeAndActiveTrue_invalidCode_returnsEmpty() {
        when(roomRepository.findByAccessCodeAndActiveTrue("WRONG")).thenReturn(Optional.empty());

        Optional<Room> found = roomRepository.findByAccessCodeAndActiveTrue("WRONG");

        assertTrue(found.isEmpty());
    }
}
