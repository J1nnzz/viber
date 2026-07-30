package com.example.viber.service;

import com.example.viber.dto.RoomResponse;
import com.example.viber.exception.ForbiddenException;
import com.example.viber.exception.NotFoundException;
import com.example.viber.model.Room;
import com.example.viber.model.RoomState;
import com.example.viber.model.User;
import com.example.viber.repository.RoomRepository;
import com.example.viber.repository.UserRepository;
import com.example.viber.utils.JwtUtil;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RoomServiceTest {

    // ── Mocks de todas las dependencias de RoomService ────────────────────────
    @Mock private RoomRepository        roomRepository;
    @Mock private UserRepository        userRepository;
    @Mock private JwtUtil               jwtUtil;
    @Mock private RoomStateService      roomStateService;
    @Mock private FirestoreChatService  firestoreChatService;
    @Mock private FirestoreQueueService firestoreQueueService;
    @Mock private SimpMessagingTemplate messagingTemplate;
    @Mock private GenreService          genreService;

    @InjectMocks
    private RoomService roomService;

    // ── Helpers ───────────────────────────────────────────────────────────────

    private Room buildPublicRoom(Long id, boolean active, boolean flagged) {
        User host = new User();
        host.setUsername("hostuser");

        Room room = new Room();
        room.setId(id);
        room.setName("Sala Publica Test");
        room.setPrivacy("PUBLIC");
        room.setActive(active);
        room.setFlagged(flagged);
        room.setHost(host);
        return room;
    }

    private Room buildPrivateRoom(Long id, String accessCode, boolean active, boolean flagged) {
        User host = new User();
        host.setUsername("hostuser");

        Room room = new Room();
        room.setId(id);
        room.setName("Sala Privada Test");
        room.setPrivacy("PRIVATE");
        room.setAccessCode(accessCode);
        room.setActive(active);
        room.setFlagged(flagged);
        room.setHost(host);
        return room;
    }

    // ── Tests: unirse a sala PÚBLICA (getRoom) ────────────────────────────────

    @Test
    void getRoom_salaPublicaActiva_devuelveRoomResponse() {
        Room room = buildPublicRoom(1L, true, false);
        when(roomRepository.findById(1L)).thenReturn(Optional.of(room));

        RoomResponse response = roomService.getRoom(1L, null);

        assertNotNull(response);
        assertEquals("Sala Publica Test", response.getName());
        assertEquals("PUBLIC", response.getPrivacy());
    }

    @Test
    void getRoom_salaPublicaCerrada_lanzaForbidden() {
        Room room = buildPublicRoom(1L, false, false);
        when(roomRepository.findById(1L)).thenReturn(Optional.of(room));

        assertThrows(ForbiddenException.class, () -> roomService.getRoom(1L, null));
    }

    @Test
    void getRoom_salaPublicaMarcadaFlagged_lanzaForbidden() {
        Room room = buildPublicRoom(1L, true, true);
        when(roomRepository.findById(1L)).thenReturn(Optional.of(room));

        assertThrows(ForbiddenException.class, () -> roomService.getRoom(1L, null));
    }

    @Test
    void getRoom_salaNoExiste_lanzaNotFoundException() {
        when(roomRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class, () -> roomService.getRoom(99L, null));
    }

    // ── Tests: unirse a sala PRIVADA por código (joinByCode) ─────────────────

    @Test
    void joinByCode_codigoValido_devuelveRoomResponse() {
        Room room = buildPrivateRoom(2L, "ABC123", true, false);
        when(roomRepository.findByAccessCodeAndActiveTrue("ABC123")).thenReturn(Optional.of(room));

        RoomResponse response = roomService.joinByCode("ABC123", "alice");

        assertNotNull(response);
        assertEquals("Sala Privada Test", response.getName());
        assertEquals("PRIVATE", response.getPrivacy());
    }

    @Test
    void joinByCode_codigoInvalido_lanzaNotFoundException() {
        when(roomRepository.findByAccessCodeAndActiveTrue("WRONG1")).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class, () -> roomService.joinByCode("WRONG1", "alice"));
    }

    @Test
    void joinByCode_salaFlagged_lanzaForbidden() {
        Room room = buildPrivateRoom(2L, "ABC123", true, true);
        when(roomRepository.findByAccessCodeAndActiveTrue("ABC123")).thenReturn(Optional.of(room));

        assertThrows(ForbiddenException.class, () -> roomService.joinByCode("ABC123", "alice"));
    }

    @Test
    void joinByCode_salaLlena_lanzaRuntimeException() {
        Room room = buildPrivateRoom(2L, "ABC123", true, false);
        room.setMaxParticipants(2);
        when(roomRepository.findByAccessCodeAndActiveTrue("ABC123")).thenReturn(Optional.of(room));

        // Simular estado con el aforo completo (2 usuarios online, máximo 2)
        RoomState fullState = new RoomState();
        fullState.setMaxParticipants(2);
        fullState.getOnlineUsers().add("user1");
        fullState.getOnlineUsers().add("user2");
        when(roomStateService.getOrCreate(2L)).thenReturn(fullState);

        assertThrows(RuntimeException.class, () -> roomService.joinByCode("ABC123", "alice"));
    }

    // ── Tests: unirse a sala PRIVADA por ID con código (getRoom) ─────────────

    @Test
    void getRoom_salaPrivadaCodigoCorrecto_devuelveRoomResponse() {
        Room room = buildPrivateRoom(3L, "XYZ999", true, false);
        when(roomRepository.findById(3L)).thenReturn(Optional.of(room));

        RoomResponse response = roomService.getRoom(3L, "XYZ999");

        assertNotNull(response);
        assertEquals("PRIVATE", response.getPrivacy());
    }

    @Test
    void getRoom_salaPrivadaCodigoIncorrecto_lanzaForbidden() {
        Room room = buildPrivateRoom(3L, "XYZ999", true, false);
        when(roomRepository.findById(3L)).thenReturn(Optional.of(room));

        assertThrows(ForbiddenException.class, () -> roomService.getRoom(3L, "WRONG1"));
    }

    @Test
    void getRoom_salaPrivadaSinCodigo_lanzaForbidden() {
        Room room = buildPrivateRoom(3L, "XYZ999", true, false);
        when(roomRepository.findById(3L)).thenReturn(Optional.of(room));

        assertThrows(ForbiddenException.class, () -> roomService.getRoom(3L, null));
    }
}
