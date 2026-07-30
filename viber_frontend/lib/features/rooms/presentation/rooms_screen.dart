import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/room.dart';
import '../infrastructure/room_service.dart';
import '../infrastructure/room_list_websocket_service.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/motion.dart';
import '../../auth/infrastructure/auth_service.dart';
import 'active_room_provider.dart';
import 'create_room_screen.dart';
import 'edit_room_sheet.dart';
import 'widgets/room_list_widgets.dart';

/// Tab "Salas" de la navegación principal.
///
/// Muestra las salas públicas activas y las salas propias del usuario (públicas + privadas).
/// Las actualizaciones de la lista llegan en tiempo real via [RoomListWebSocketService]
/// (canal /topic/rooms) para que no sea necesario hacer polling manual.
/// También permite unirse a salas privadas por código de acceso.
class RoomsScreen extends StatefulWidget {
  final Function(Room) onEnterRoom;
  const RoomsScreen({super.key, required this.onEnterRoom});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _roomService    = RoomService();
  final _authService    = AuthService();
  final _codeController = TextEditingController();
  List<Room> _rooms          = [];
  List<Room> _myPrivateRooms = [];
  List<Room> _recommended    = [];
  String? _myUsername;
  bool _loading = true;
  Timer? _refreshTimer;
  RoomListWebSocketService? _listWs;

  // Salas públicas del usuario (del feed) + sus salas privadas
  List<Room> get _myRooms => [
        ..._rooms.where(_isMyRoom),
        ..._myPrivateRooms,
      ];

  // Salas del día: las 5 con más oyentes, o las más recientes si no hay
  List<Room> get _featuredRooms {
    final sorted = [..._rooms]..sort((a, b) {
        final byListeners = b.listenerCount.compareTo(a.listenerCount);
        if (byListeners != 0) return byListeners;
        return b.createdAt.compareTo(a.createdAt);
      });
    return sorted.take(5).toList();
  }

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
        if (mounted) setState(() => _rooms.insert(0, room));
      };
      _listWs!.onRoomUpdated = (room) {
        if (!mounted) return;
        setState(() {
          final idx = _rooms.indexWhere((r) => r.id == room.id);
          if (idx != -1) _rooms[idx] = room;
        });
      };
      _listWs!.onRoomClosed = (roomId) {
        if (mounted) setState(() => _rooms.removeWhere((r) => r.id == roomId));
      };
      _listWs!.connect();
    } catch (_) {}
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _listWs?.disconnect();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _roomService.getPublicRooms(),
        _roomService.getMyRooms(),
      ]);
      final publicRooms = results[0];
      final myRooms     = results[1];
      // Solo guardamos en _myPrivateRooms las privadas (las públicas ya están en _rooms)
      final privateOwn = myRooms.where((r) => r.isPrivate).toList();
      if (mounted) setState(() {
        _rooms          = publicRooms;
        _myPrivateRooms = privateOwn;
      });
      _loadRecommended();
    } catch (_) {
      if (!silent) _showError('Error al cargar salas');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  // Recomendaciones por gusto: opcionales. Si fallan (usuario sin historial,
  // backend ocupado, etc.) no molestamos al usuario — la lista normal sigue ahí.
  Future<void> _loadRecommended() async {
    try {
      final recs = await _roomService.getRecommendedRooms();
      if (mounted) setState(() => _recommended = recs);
    } catch (_) {}
  }

  void _showJoinByCodeDialog() {
    _codeController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('rooms.join_dialog_title'.tr()),
        content: TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'rooms.code_placeholder'.tr(),
            prefixIcon: const Icon(Icons.vpn_key_outlined),
          ),
          onSubmitted: (_) => _joinByCode(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.login_rounded, size: 16),
            label: Text('common.join'.tr()),
            onPressed: () => _joinByCode(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _joinByCode(BuildContext ctx) async {
    Navigator.pop(ctx);
    try {
      final room = await _roomService
          .joinByCode(_codeController.text.trim().toUpperCase());
      widget.onEnterRoom(room);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Room?> _openCreateRoom() => Navigator.push<Room>(
        context,
        fadeThroughRoute<Room>(const CreateRoomScreen()),
      );

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
        _rooms.removeWhere((r) => r.id == room.id);
        _myPrivateRooms.removeWhere((r) => r.id == room.id);
      });
    } else if (result is Room) {
      setState(() {
        final pubIdx = _rooms.indexWhere((r) => r.id == room.id);
        if (pubIdx != -1) _rooms[pubIdx] = result;
        final privIdx = _myPrivateRooms.indexWhere((r) => r.id == room.id);
        if (privIdx != -1) _myPrivateRooms[privIdx] = result;
      });
    }
  }

  Future<void> _closeRoomFromCard(Room room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('rooms.close_dialog_title'.tr()),
        content: Text('rooms.close_confirmation'.tr(args: [room.name])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('rooms.close_button'.tr(),
                style: const TextStyle(color: appError)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _roomService.closeRoom(room.id);
      if (mounted) setState(() {
        _rooms.removeWhere((r) => r.id == room.id);
        _myPrivateRooms.removeWhere((r) => r.id == room.id);
      });
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _tryEnterRoom(Room room) {
    final isFull = room.maxParticipants != null &&
        room.listenerCount >= room.maxParticipants! &&
        room.hostUsername != _myUsername;
    if (isFull) {
      _showError('rooms.room_full_error'.tr(args: [
        room.name,
        '${room.listenerCount}',
        '${room.maxParticipants}',
      ]));
      return;
    }
    widget.onEnterRoom(room);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: appError, size: 16),
          const SizedBox(width: spacingSm),
          Expanded(child: Text(msg)),
        ],
      ),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('rooms.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'rooms.join_code_tooltip'.tr(),
            onPressed: _showJoinByCodeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'common.refresh'.tr(),
            onPressed: _loadRooms,
          ),
        ],
      ),
      floatingActionButton: Consumer<ActiveRoomProvider>(
        builder: (context, activeRoom, _) {
          final miniPlayerVisible = activeRoom.isActive && activeRoom.isMinimized;
          return Padding(
            padding: EdgeInsets.only(bottom: miniPlayerVisible ? 80.0 : 0.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [appMagenta, appPurple],
                ),
                borderRadius: BorderRadius.circular(radiusFull),
                boxShadow: [
                  BoxShadow(
                    color: appPurple.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'rooms.create_button'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
                ),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                onPressed: () async {
                final created = await _openCreateRoom();
                if (created != null) {
                  setState(() {
                    if (created.isPrivate) {
                      _myPrivateRooms.insert(0, created);
                    } else {
                      _rooms.insert(0, created);
                    }
                  });
                  widget.onEnterRoom(created);
                }
              },
              ),
            ),
          );
        },
      ),
      body: _loading
          ? const _RoomsSkeleton()
          : _rooms.isEmpty && _myPrivateRooms.isEmpty
              ? _EmptyState(
                  onCreateRoom: _openCreateRoom,
                  onRoomCreated: (room) {
                    setState(() {
                      if (room.isPrivate) {
                        _myPrivateRooms.insert(0, room);
                      } else {
                        _rooms.insert(0, room);
                      }
                    });
                    widget.onEnterRoom(room);
                  },
                )
              : RefreshIndicator(
                  onRefresh: _loadRooms,
                  color: appAccent,
                  child: CustomScrollView(
                    slivers: [
                      // ── Carrusel "Salas del día" ───────────────────────────
                      SliverToBoxAdapter(
                        child: _FeaturedSection(
                          rooms: _featuredRooms,
                          onEnterRoom: _tryEnterRoom,
                          isMyRoom: _isMyRoom,
                          onEdit:  _openEditSheet,
                          onClose: _closeRoomFromCard,
                        ),
                      ),

                      // ── Sección "Salas para ti" (recomendadas) ─────────────
                      if (_recommended.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _RecommendedSection(
                            rooms: _recommended,
                            onEnterRoom: _tryEnterRoom,
                          ),
                        ),

                      // ── Sección "Tus salas" ────────────────────────────────
                      if (_myRooms.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                spacingMd, spacingMd, spacingMd, spacingSm),
                            child: Row(
                              children: [
                                Icon(Icons.manage_accounts_rounded,
                                    color: context.appTextSecColor, size: 18),
                                const SizedBox(width: spacingXs),
                                Text(
                                  'rooms.my_rooms_section'.tr(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: spacingSm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.appCard2Color,
                                    borderRadius:
                                        BorderRadius.circular(radiusFull),
                                  ),
                                  child: Text(
                                    '${_myRooms.length}',
                                    style: TextStyle(
                                      color: context.appTextSecColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                              spacingMd, 0, spacingMd, spacingSm),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: spacingMd),
                                child: RoomListCard(
                                  room: _myRooms[i],
                                  onTap: () => _tryEnterRoom(_myRooms[i]),
                                  onEdit:  _openEditSheet,
                                  onClose: _closeRoomFromCard,
                                ),
                              ),
                              childCount: _myRooms.length,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Divider(
                              color: appDivider,
                              height: 1),
                        ),
                      ],

                      // ── Cabecera "Todas las salas" ─────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              spacingMd, spacingMd, spacingMd, spacingSm),
                          child: Row(
                            children: [
                              Text(
                                'rooms.all_rooms_section'.tr(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: spacingSm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.appCard2Color,
                                  borderRadius:
                                      BorderRadius.circular(radiusFull),
                                ),
                                child: Text(
                                  '${_rooms.length}',
                                  style: TextStyle(
                                    color: context.appTextSecColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Lista de salas ─────────────────────────────────────
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            spacingMd, 0, spacingMd, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: spacingMd),
                              child: AppEntrance(
                                delay: Duration(
                                    milliseconds: (i.clamp(0, 8)) * 45),
                                child: RoomListCard(
                                  room: _rooms[i],
                                  onTap: () => _tryEnterRoom(_rooms[i]),
                                  onEdit:  _isMyRoom(_rooms[i]) ? _openEditSheet  : null,
                                  onClose: _isMyRoom(_rooms[i]) ? _closeRoomFromCard : null,
                                ),
                              ),
                            ),
                            childCount: _rooms.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ── Sección "Salas para ti" (recomendadas por gusto) ──────────────────────────

class _RecommendedSection extends StatelessWidget {
  final List<Room> rooms;
  final Function(Room) onEnterRoom;

  const _RecommendedSection({required this.rooms, required this.onEnterRoom});

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              spacingMd, spacingMd, spacingMd, spacingSm),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: appAccent, size: 18),
              const SizedBox(width: spacingXs),
              Text(
                'rooms.recommended_section'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: spacingMd),
            itemCount: rooms.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: spacingMd),
              child: RoomFeaturedCard(
                room: rooms[i],
                onTap: () => onEnterRoom(rooms[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: spacingSm),
        Divider(color: appDivider, height: 1),
      ],
    );
  }
}

// ── Sección carrusel destacado ────────────────────────────────────────────────

class _FeaturedSection extends StatelessWidget {
  final List<Room> rooms;
  final Function(Room) onEnterRoom;
  final bool Function(Room)? isMyRoom;
  final void Function(Room)? onEdit;
  final void Function(Room)? onClose;

  const _FeaturedSection({
    required this.rooms,
    required this.onEnterRoom,
    this.isMyRoom,
    this.onEdit,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              spacingMd, spacingMd, spacingMd, spacingSm),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: appEnergy, shape: BoxShape.circle),
              ),
              const SizedBox(width: spacingXs),
              Text(
                'rooms.featured_section'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: spacingMd),
            itemCount: rooms.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: spacingMd),
              child: RoomFeaturedCard(
                room: rooms[i],
                onTap: () => onEnterRoom(rooms[i]),
                onEdit:  (isMyRoom?.call(rooms[i]) ?? false) && onEdit  != null ? (_) => onEdit!(rooms[i])  : null,
                onClose: (isMyRoom?.call(rooms[i]) ?? false) && onClose != null ? (_) => onClose!(rooms[i]) : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: spacingSm),
        Divider(color: appDivider, height: 1),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Future<Room?> Function() onCreateRoom;
  final void Function(Room) onRoomCreated;

  const _EmptyState({required this.onCreateRoom, required this.onRoomCreated});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: appAccentGlow,
                borderRadius: BorderRadius.circular(radiusXl),
              ),
              child: const Icon(
                Icons.headphones_rounded,
                color: appAccent,
                size: 34,
              ),
            ),
            const SizedBox(height: spacingLg),
            Text(
              'rooms.empty_title'.tr(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: spacingXs),
            Text(
              'rooms.empty_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.55,
              ),
            ),
            const SizedBox(height: spacingXl),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('rooms.create_empty_button'.tr()),
              onPressed: () async {
                final created = await onCreateRoom();
                if (created != null) onRoomCreated(created);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton de carga ─────────────────────────────────────────────────────────
// Silueta con shimmer que imita el carrusel destacado + la lista de salas.
// Sustituye al spinner suelto: el contenido "aparece" en su sitio, sin salto
// de layout y con sensación de mayor rapidez.

class _RoomsSkeleton extends StatelessWidget {
  const _RoomsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de sección "Salas del día"
          const Padding(
            padding: EdgeInsets.fromLTRB(spacingMd, spacingMd, spacingMd, spacingSm),
            child: ShimmerBox(width: 120, height: 16),
          ),
          // Carrusel destacado
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: spacingMd),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, _) => Padding(
                padding: const EdgeInsets.only(right: spacingMd),
                child: ShimmerBox(
                  width: 190,
                  height: 200,
                  borderRadius: BorderRadius.circular(radiusLg),
                ),
              ),
            ),
          ),
          const SizedBox(height: spacingLg),
          const Padding(
            padding: EdgeInsets.fromLTRB(spacingMd, 0, spacingMd, spacingSm),
            child: ShimmerBox(width: 140, height: 16),
          ),
          // Tarjetas de lista
          ...List.generate(
            4,
            (_) => const Padding(
              padding: EdgeInsets.fromLTRB(spacingMd, 0, spacingMd, spacingMd),
              child: _SkeletonRoomCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonRoomCard extends StatelessWidget {
  const _SkeletonRoomCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(spacingMd),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: context.appDividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(
            width: 64,
            height: 64,
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          const SizedBox(width: spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 160, height: 14),
                const SizedBox(height: spacingSm),
                const ShimmerBox(width: 100, height: 11),
                const SizedBox(height: spacingMd),
                ShimmerBox(
                  width: 90,
                  height: 20,
                  borderRadius: BorderRadius.circular(radiusFull),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
