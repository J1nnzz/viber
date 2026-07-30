import 'package:flutter/foundation.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/domain/room_state.dart';

/// Fuente de verdad para la sala activa.
///
/// Elevado al árbol raíz de la app, sobrevive a cualquier navegación.
/// RoomScreen escribe aquí; MiniPlayer y AppShell solo leen.
class ActiveRoomProvider extends ChangeNotifier {
  // ── Estado ────────────────────────────────────────────────────────────────
  Room?      _room;
  RoomState  _roomState = const RoomState();
  String?    _currentVideoTitle;
  String?    _currentVideoThumbnail;
  bool       _playing        = false;
  bool       _connected      = false;
  bool       _isMinimized    = false;
  int        _listenerCount  = 0;
  double     _currentSeconds = 0;
  double     _totalSeconds   = 0;
  String?    _currentUsername;
  String?    _kickedRoomName;     // nombre de sala de la que el usuario fue expulsado
  String?    _roomClosedName;    // nombre de sala cerrada por el host
  String?    _roomFullName;      // nombre de sala llena que rechazó la entrada

  Room?      get room                  => _room;
  RoomState  get roomState             => _roomState;
  String?    get currentVideoTitle     => _currentVideoTitle;
  String?    get currentVideoThumbnail => _currentVideoThumbnail;
  bool       get playing               => _playing;
  bool       get connected             => _connected;
  bool       get isMinimized           => _isMinimized;
  bool       get isActive              => _room != null;
  int        get listenerCount         => _listenerCount;
  double     get currentSeconds        => _currentSeconds;
  double     get totalSeconds          => _totalSeconds;
  String?    get currentUsername       => _currentUsername;
  String?    get kickedRoomName        => _kickedRoomName;
  String?    get roomClosedName        => _roomClosedName;
  String?    get roomFullName          => _roomFullName;
  bool       get isCurrentUserHost     =>
      _currentUsername != null && _roomState.isHost(_currentUsername!);

  // ── Callback para que MiniPlayer controle el player ──────────────────────
  VoidCallback? onTogglePlayPause;

  // ── API pública ───────────────────────────────────────────────────────────

  void joinRoom(Room room) {
    _room        = room;
    _isMinimized = false;
    notifyListeners();
  }

  void updatePlayback({
    required RoomState roomState,
    required bool      playing,
    required bool      connected,
    required int       listenerCount,
    required double    currentSeconds,
    required double    totalSeconds,
    String?            currentUsername,
  }) {
    _roomState             = roomState;
    _currentVideoTitle     = roomState.currentVideoTitle;
    _currentVideoThumbnail = roomState.currentVideoThumbnail;
    _playing               = playing;
    _connected             = connected;
    _listenerCount         = listenerCount;
    _currentSeconds        = currentSeconds;
    _totalSeconds          = totalSeconds;
    if (currentUsername != null) _currentUsername = currentUsername;
    notifyListeners();
  }

  void minimize() {
    _isMinimized = true;
    notifyListeners();
  }

  void expand() {
    _isMinimized = false;
    notifyListeners();
  }

  /// Salida normal de la sala.
  void leaveRoom() {
    _resetState();
  }

  /// El usuario fue expulsado: guarda el nombre de sala para mostrar aviso.
  void setKickedFromRoom(String roomName) {
    _kickedRoomName = roomName;
    _resetState();
  }

  /// Llamar tras haber mostrado el aviso de expulsión.
  void clearKicked() {
    _kickedRoomName = null;
    notifyListeners();
  }

  /// Entrada rechazada porque la sala está llena.
  void setRoomFull(String roomName) {
    _roomFullName = roomName;
    _resetState();
  }

  /// Llamar tras haber mostrado el aviso de sala llena.
  void clearRoomFull() {
    _roomFullName = null;
    notifyListeners();
  }

  /// El host cerró la sala: guarda el nombre para mostrar aviso.
  void setRoomClosedByHost(String roomName) {
    _roomClosedName = roomName;
    _resetState();
  }

  /// Llamar tras haber mostrado el aviso de sala cerrada.
  void clearRoomClosed() {
    _roomClosedName = null;
    notifyListeners();
  }

  void _resetState() {
    _room                  = null;
    _roomState             = const RoomState();
    _currentVideoTitle     = null;
    _currentVideoThumbnail = null;
    _playing               = false;
    _connected             = false;
    _isMinimized           = false;
    _listenerCount         = 0;
    _currentSeconds        = 0;
    _totalSeconds          = 0;
    onTogglePlayPause      = null;
    _currentUsername       = null;
    _roomFullName          = null;
    notifyListeners();
  }
}
