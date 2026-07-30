import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../domain/room.dart';
import '../infrastructure/room_service.dart';
import '../infrastructure/room_list_websocket_service.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/motion.dart';
import '../../auth/infrastructure/auth_service.dart';
import 'edit_room_sheet.dart';
import 'widgets/room_list_widgets.dart';

/// Tab "Explorar" de la navegación principal.
///
/// Carga todas las salas públicas y permite filtrarlas por nombre o género
/// con búsqueda en tiempo real (sin llamada al servidor — filtrado local).
/// También recibe actualizaciones en tiempo real via WebSocket.
class ExploreScreen extends StatefulWidget {
  final Function(Room) onEnterRoom;
  const ExploreScreen({super.key, required this.onEnterRoom});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _roomService  = RoomService();
  final _authService  = AuthService();
  final _searchCtrl   = TextEditingController();
  final _searchFocus  = FocusNode();
  String? _myUsername;

  List<Room> _allRooms = [];
  List<Room> _results  = [];
  bool _loading        = true;
  bool _searching      = false;
  Timer? _refreshTimer;
  RoomListWebSocketService? _listWs;

  // Filtros
  _SortOrder _sortOrder  = _SortOrder.listeners;
  int?       _maxPeople;
  bool       _onlyActive = false;

  @override
  void initState() {
    super.initState();
    _loadUsernameAndConnect();
    _loadRooms();
    // Polling como fallback (WS desconectado, servidor reiniciado, etc.)
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _loadRooms(silent: true),
    );
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _listWs?.disconnect();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadUsernameAndConnect() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      final parts = token.split('.');
      if (parts.length < 2) return;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      if (mounted) setState(() => _myUsername = payload['sub'] as String?);

      _listWs = RoomListWebSocketService(token: token);
      _listWs!.onRoomCreated = (room) {
        if (!mounted) return;
        setState(() {
          _allRooms.insert(0, room);
          _applyFilters();
        });
      };
      _listWs!.onRoomUpdated = (room) {
        if (!mounted) return;
        setState(() {
          final idx = _allRooms.indexWhere((r) => r.id == room.id);
          if (idx != -1) _allRooms[idx] = room;
          _applyFilters();
        });
      };
      _listWs!.onRoomClosed = (roomId) {
        if (!mounted) return;
        setState(() {
          _allRooms.removeWhere((r) => r.id == roomId);
          _applyFilters();
        });
      };
      _listWs!.connect();
    } catch (_) {}
  }

  bool _isMyRoom(Room room) =>
      _myUsername != null && room.hostUsername == _myUsername;

  Future<void> _openEditSheet(Room room) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditRoomSheet(room: room),
    );
    if (!mounted) return;
    if (result == EditRoomSheet.kClosed) {
      setState(() {
        _allRooms.removeWhere((r) => r.id == room.id);
        _applyFilters();
      });
    } else if (result is Room) {
      setState(() {
        final idx = _allRooms.indexWhere((r) => r.id == room.id);
        if (idx != -1) _allRooms[idx] = result;
        _applyFilters();
      });
    }
  }

  Future<void> _closeRoomFromCard(Room room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Cerrar la sala?'),
        content: Text(
          'Se cerrará "${room.name}" permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sala',
                style: TextStyle(color: appError)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _roomService.closeRoom(room.id);
      if (mounted) setState(() {
        _allRooms.removeWhere((r) => r.id == room.id);
        _applyFilters();
      });
    } catch (_) {}
  }

  Future<void> _loadRooms({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final rooms = await _roomService.getPublicRooms();
      if (!mounted) return;
      setState(() {
        _allRooms = rooms;
        _applyFilters();
      });
    } catch (_) {}
    finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searching = _searchCtrl.text.isNotEmpty;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    var filtered = _allRooms.where((r) {
      if (query.isNotEmpty) {
        final matchName  = r.name.toLowerCase().contains(query);
        final matchGenre = r.genres.any((g) => g.toLowerCase().contains(query));
        final matchHost  = r.hostUsername.toLowerCase().contains(query);
        if (!matchName && !matchGenre && !matchHost) return false;
      }
      if (_onlyActive && r.listenerCount == 0) return false;
      if (_maxPeople != null && r.maxParticipants != null &&
          r.maxParticipants! > _maxPeople!) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOrder) {
        case _SortOrder.listeners:
          return b.listenerCount.compareTo(a.listenerCount);
        case _SortOrder.newest:
          return b.createdAt.compareTo(a.createdAt);
        case _SortOrder.oldest:
          return a.createdAt.compareTo(b.createdAt);
        case _SortOrder.nameAZ:
          return a.name.compareTo(b.name);
      }
    });

    _results = filtered;
  }

  List<String> get _genres {
    final seen = <String>{};
    final genres = <String>[];
    for (final room in _allRooms) {
      for (final g in room.genres) {
        if (seen.add(g)) genres.add(g);
      }
    }
    return genres;
  }

  List<Room> _roomsByGenre(String genre) =>
      _allRooms.where((r) => r.genres.contains(genre)).toList()
        ..sort((a, b) => b.listenerCount.compareTo(a.listenerCount));

  bool get _hasActiveFilters =>
      _sortOrder != _SortOrder.listeners || _maxPeople != null || _onlyActive;

  void _openFilterSheet() {
    var tmpOrder  = _sortOrder;
    var tmpMax    = _maxPeople;
    var tmpActive = _onlyActive;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(radiusXl)),
            border: Border(top: BorderSide(color: appDivider)),
          ),
          padding: EdgeInsets.fromLTRB(
              spacingMd,
              spacingMd,
              spacingMd,
              spacingMd + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: spacingMd),
              Text(
                'Filtrar salas',
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: spacingLg),

              // Ordenar por
              Text('Ordenar por',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
              const SizedBox(height: spacingSm),
              Wrap(
                spacing: spacingSm,
                runSpacing: spacingXs,
                children: _SortOrder.values.map((o) {
                  final sel = tmpOrder == o;
                  return GestureDetector(
                    onTap: () => setSheet(() => tmpOrder = o),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? appAccent : Theme.of(ctx).colorScheme.surface,
                        borderRadius: BorderRadius.circular(radiusFull),
                        border: Border.all(
                            color: sel ? appAccent : appDivider),
                      ),
                      child: Text(
                        o.label,
                        style: TextStyle(
                          color: sel ? Colors.white : Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: spacingLg),

              // Solo activas
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Solo salas activas',
                            style: TextStyle(
                                color: Theme.of(ctx).colorScheme.onSurface, fontSize: 14)),
                        Text('Con al menos 1 oyente',
                            style: TextStyle(
                                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: tmpActive,
                    onChanged: (v) => setSheet(() => tmpActive = v),
                    activeColor: appAccent,
                  ),
                ],
              ),
              const SizedBox(height: spacingMd),

              // Máx. participantes
              Text('Máx. participantes',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
              const SizedBox(height: spacingSm),
              Wrap(
                spacing: spacingSm,
                runSpacing: spacingXs,
                children: [null, 5, 10, 20, 50].map((v) {
                  final sel = tmpMax == v;
                  final label = v == null ? 'Todos' : '≤$v';
                  return GestureDetector(
                    onTap: () => setSheet(() => tmpMax = v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? appAccent : Theme.of(ctx).colorScheme.surface,
                        borderRadius: BorderRadius.circular(radiusFull),
                        border: Border.all(
                            color: sel ? appAccent : appDivider),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: sel ? Colors.white : Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: spacingLg),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setSheet(() {
                        tmpOrder  = _SortOrder.listeners;
                        tmpMax    = null;
                        tmpActive = false;
                      }),
                      child: const Text('Resetear'),
                    ),
                  ),
                  const SizedBox(width: spacingMd),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _sortOrder  = tmpOrder;
                          _maxPeople  = tmpMax;
                          _onlyActive = tmpActive;
                          _applyFilters();
                        });
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Explorar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refrescar',
            onPressed: _loadRooms,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: appAccent, strokeWidth: 2))
          : Column(
              children: [
                // ── Búsqueda + filtro ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      spacingMd, spacingMd, spacingMd, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Buscar sala, género, host…',
                            prefixIcon: const Icon(Icons.search_rounded,
                                size: 20),
                            suffixIcon: _searching
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _searchFocus.unfocus();
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: spacingSm),
                      _FilterButton(
                        active: _hasActiveFilters,
                        onTap: _openFilterSheet,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: spacingMd),

                // ── Resultados o carruseles ────────────────────────────────
                Expanded(
                  child: _searching || _hasActiveFilters
                      ? _SearchResults(
                          results: _results,
                          onEnterRoom: widget.onEnterRoom,
                          isMyRoom: _isMyRoom,
                          onEdit: _openEditSheet,
                          onClose: _closeRoomFromCard,
                        )
                      : _GenreCarousels(
                          genres: _genres,
                          roomsByGenre: _roomsByGenre,
                          allRooms: _allRooms,
                          onEnterRoom: widget.onEnterRoom,
                          isMyRoom: _isMyRoom,
                          onEdit: _openEditSheet,
                          onClose: _closeRoomFromCard,
                        ),
                ),
              ],
            ),
    );
  }
}

// ── Botón filtro ──────────────────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _FilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: active ? appAccent : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(color: active ? appAccent : appDivider),
        ),
        child: Icon(
          Icons.tune_rounded,
          color: active ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          size: 20,
        ),
      ),
    );
  }
}

// ── Resultados de búsqueda ────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  final List<Room> results;
  final Function(Room) onEnterRoom;
  final bool Function(Room)? isMyRoom;
  final void Function(Room)? onEdit;
  final void Function(Room)? onClose;

  const _SearchResults({
    required this.results,
    required this.onEnterRoom,
    this.isMyRoom,
    this.onEdit,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), size: 40),
            const SizedBox(height: spacingMd),
            Text('Sin resultados',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 15)),
            const SizedBox(height: spacingXs),
            Text('Prueba con otro término o quita los filtros',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding:
          const EdgeInsets.fromLTRB(spacingMd, 0, spacingMd, 100),
      itemCount: results.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: spacingMd),
        child: AppEntrance(
          delay: Duration(milliseconds: (i.clamp(0, 8)) * 45),
          child: RoomListCard(
            room: results[i],
            onTap: () => onEnterRoom(results[i]),
            onEdit:  (isMyRoom?.call(results[i]) ?? false) ? onEdit  : null,
            onClose: (isMyRoom?.call(results[i]) ?? false) ? onClose : null,
          ),
        ),
      ),
    );
  }
}

// ── Carruseles por género ─────────────────────────────────────────────────────

class _GenreCarousels extends StatelessWidget {
  final List<String> genres;
  final List<Room> Function(String) roomsByGenre;
  final List<Room> allRooms;
  final Function(Room) onEnterRoom;
  final bool Function(Room)? isMyRoom;
  final void Function(Room)? onEdit;
  final void Function(Room)? onClose;

  const _GenreCarousels({
    required this.genres,
    required this.roomsByGenre,
    required this.allRooms,
    required this.onEnterRoom,
    this.isMyRoom,
    this.onEdit,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final liveRooms = [...allRooms]
      ..sort((a, b) => b.listenerCount.compareTo(a.listenerCount));
    final hasLive = liveRooms.any((r) => r.listenerCount > 0);

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (hasLive) ...[
          _SectionHeader(
            icon: Icons.radio_rounded,
            iconColor: appEnergy,
            title: 'En vivo ahora',
          ),
          _HorizontalCarousel(
            rooms: liveRooms.where((r) => r.listenerCount > 0).toList(),
            onEnterRoom: onEnterRoom,
            isMyRoom: isMyRoom,
            onEdit: onEdit,
            onClose: onClose,
          ),
          const SizedBox(height: spacingMd),
          Divider(color: appDivider, height: 1),
          const SizedBox(height: spacingMd),
        ],
        for (final genre in genres) ...[
          _SectionHeader(
            icon: Icons.queue_music_rounded,
            iconColor: context.appTextSecColor,
            title: genre,
          ),
          _HorizontalCarousel(
            rooms: roomsByGenre(genre),
            onEnterRoom: onEnterRoom,
            isMyRoom: isMyRoom,
            onEdit: onEdit,
            onClose: onClose,
          ),
          const SizedBox(height: spacingMd),
        ],
        if (genres.isEmpty) ...[
          _SectionHeader(
            icon: Icons.headphones_rounded,
            iconColor: context.appTextSecColor,
            title: 'Todas las salas',
          ),
          _HorizontalCarousel(
            rooms: allRooms,
            onEnterRoom: onEnterRoom,
            isMyRoom: isMyRoom,
            onEdit: onEdit,
            onClose: onClose,
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          spacingMd, 0, spacingMd, spacingSm),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: spacingXs),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalCarousel extends StatelessWidget {
  final List<Room> rooms;
  final Function(Room) onEnterRoom;
  final bool Function(Room)? isMyRoom;
  final void Function(Room)? onEdit;
  final void Function(Room)? onClose;

  const _HorizontalCarousel({
    required this.rooms,
    required this.onEnterRoom,
    this.isMyRoom,
    this.onEdit,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: spacingMd),
        child: Text('Sin salas en esta categoría',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 13)),
      );
    }

    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: spacingMd),
        itemCount: rooms.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: spacingMd),
          child: RoomFeaturedCard(
            room: rooms[i],
            onTap: () => onEnterRoom(rooms[i]),
            onEdit:  (isMyRoom?.call(rooms[i]) ?? false) ? onEdit  : null,
            onClose: (isMyRoom?.call(rooms[i]) ?? false) ? onClose : null,
          ),
        ),
      ),
    );
  }
}

// ── Sort enum ─────────────────────────────────────────────────────────────────

enum _SortOrder { listeners, newest, oldest, nameAZ }

extension _SortOrderLabel on _SortOrder {
  String get label {
    switch (this) {
      case _SortOrder.listeners: return 'Más oyentes';
      case _SortOrder.newest:    return 'Más recientes';
      case _SortOrder.oldest:    return 'Más antiguas';
      case _SortOrder.nameAZ:    return 'Nombre A-Z';
    }
  }
}
