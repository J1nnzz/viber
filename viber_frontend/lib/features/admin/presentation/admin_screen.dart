import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:viber/core/constants/api_constants.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/features/auth/infrastructure/auth_service.dart';
import 'package:viber/features/rooms/domain/room.dart';
import 'package:viber/features/rooms/presentation/room_screen.dart';
import 'quiz_pool_page.dart';

/// Panel de administración accesible solo para usuarios con rol ADMIN.
///
/// Organizado en pestañas: gestión de salas (con opción de cerrar, flagear,
/// echar usuarios), gestión de reportes (marcar como resueltos),
/// gestión de géneros (añadir/borrar) y gestión de usuarios (cambiar rol).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;
  final _authService = AuthService();

  Future<String> _getAuthHeader() async {
    final token = await _authService.getToken();
    return 'Bearer $token';
  }

  // Getter y no `static const`: las etiquetas se traducen con .tr(), que debe
  // reevaluarse en cada build para que cambiar de idioma las actualice. Una
  // lista constante las congelaría con el idioma que hubiera al arrancar.
  static List<({IconData icon, IconData selectedIcon, String label})> get _sections => [
    (icon: Icons.music_note_outlined,     selectedIcon: Icons.music_note,     label: 'admin.section_genres'.tr()),
    (icon: Icons.meeting_room_outlined,   selectedIcon: Icons.meeting_room,   label: 'admin.section_rooms'.tr()),
    (icon: Icons.people_outline,          selectedIcon: Icons.people,         label: 'admin.section_users'.tr()),
    (icon: Icons.sports_esports_outlined, selectedIcon: Icons.sports_esports, label: 'admin.section_quiz'.tr()),
  ];

  @override
  Widget build(BuildContext context) {
    final body = switch (_selectedIndex) {
      0 => _GenresPage(getAuthHeader: _getAuthHeader),
      1 => _RoomsPage(getAuthHeader: _getAuthHeader),
      2 => _UsersPage(getAuthHeader: _getAuthHeader),
      _ => QuizPoolPage(getAuthHeader: _getAuthHeader),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('admin.title'.tr()),
        centerTitle: false,
      ),
      body: Row(
        children: [
          // ── NavigationRail lateral ─────────────────────────────────────
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final s in _sections)
                NavigationRailDestination(
                  icon:         Icon(s.icon),
                  selectedIcon: Icon(s.selectedIcon),
                  label:        Text(s.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          // ── Contenido ──────────────────────────────────────────────────
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// GÉNEROS
// ════════════════════════════════════════════════════════════════════════════

class _GenresPage extends StatefulWidget {
  final Future<String> Function() getAuthHeader;
  const _GenresPage({required this.getAuthHeader});

  @override
  State<_GenresPage> createState() => _GenresPageState();
}

class _GenresPageState extends State<_GenresPage> {
  List<dynamic> _genres = [];
  bool _loading = true;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/genres'));
      if (res.statusCode == 200 && mounted) {
        setState(() => _genres = jsonDecode(res.body));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final auth = await widget.getAuthHeader();
    final res = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/admin/genres'),
      headers: {'Content-Type': 'application/json', 'Authorization': auth},
      body: jsonEncode({'name': name}),
    );
    if (res.statusCode == 200) {
      _nameCtrl.clear();
      _load();
    } else {
      if (mounted) _snack(jsonDecode(res.body)['error'] ?? 'Error', error: true);
    }
  }

  Future<void> _delete(dynamic id, String name) async {
    if (!await _confirm('¿Eliminar el género "$name"?')) return;
    final auth = await widget.getAuthHeader();
    final res = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/admin/genres/$id'),
      headers: {'Authorization': auth},
    );
    if (res.statusCode == 200) {
      _load();
    } else {
      if (mounted) _snack(jsonDecode(res.body)['error'] ?? 'Error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Catálogo de géneros',
          subtitle: '${_genres.length} géneros registrados',
          icon: Icons.music_note,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'admin.new_genre'.tr(),
                    hintText: 'admin.genre_hint'.tr(),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add, size: 18),
                label: Text('common.add'.tr()),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _genres.isEmpty
                  ? _Empty(icon: Icons.music_off, text: 'No hay géneros todavía')
                  : ListView.separated(
                      itemCount: _genres.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) {
                        final g = _genres[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(
                              (g['name'] as String)[0].toUpperCase(),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          title: Text(g['name']),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'admin.delete_genre'.tr(),
                            onPressed: () => _delete(g['id'], g['name']),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  Future<bool> _confirm(String msg) => _showConfirm(context, msg);
}

// ════════════════════════════════════════════════════════════════════════════
// SALAS
// ════════════════════════════════════════════════════════════════════════════

enum _RoomFilter { all, active, closed, flagged }

class _RoomsPage extends StatefulWidget {
  final Future<String> Function() getAuthHeader;
  const _RoomsPage({required this.getAuthHeader});

  @override
  State<_RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<_RoomsPage> {
  List<dynamic> _rooms   = [];
  List<dynamic> _reports = [];
  bool _loading         = true;
  _RoomFilter _filter   = _RoomFilter.all;
  String _search        = '';
  bool _filterReports   = false; // mostrar solo salas con reportes pendientes

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final auth = await widget.getAuthHeader();
      // Carga salas y reportes en paralelo
      final results = await Future.wait([
        http.get(Uri.parse('${ApiConstants.baseUrl}/admin/rooms'),
            headers: {'Authorization': auth}),
        http.get(Uri.parse('${ApiConstants.baseUrl}/admin/reports?pending=false'),
            headers: {'Authorization': auth}),
      ]);
      if (mounted) {
        setState(() {
          if (results[0].statusCode == 200) _rooms   = jsonDecode(results[0].body);
          if (results[1].statusCode == 200) _reports = jsonDecode(results[1].body);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    return _rooms.where((r) {
      final active  = r['active']  == true;
      final flagged = r['flagged'] == true;
      final matchFilter = switch (_filter) {
        _RoomFilter.all     => true,
        _RoomFilter.active  => active && !flagged,
        _RoomFilter.closed  => !active,
        _RoomFilter.flagged => flagged,
      };
      if (!matchFilter) return false;
      if (_filterReports) {
        final hasPending = _reports.any(
            (rep) => rep['roomId'] == r['id'] && rep['resolved'] != true);
        if (!hasPending) return false;
      }
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return (r['name']         as String? ?? '').toLowerCase().contains(q) ||
             (r['hostUsername'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<dynamic> _reportsForRoom(dynamic roomId) =>
      _reports.where((r) => r['roomId'] == roomId).toList();

  Future<void> _resolveReport(dynamic reportId) async {
    final auth = await widget.getAuthHeader();
    final res  = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/admin/reports/$reportId/resolve'),
      headers: {'Authorization': auth},
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      // Actualiza solo el reporte en el estado local — sin recargar toda la página
      setState(() {
        final idx = _reports.indexWhere((r) => r['id'] == reportId);
        if (idx != -1) {
          _reports[idx] = {..._reports[idx], 'resolved': true};
        }
      });
    } else {
      _snack('errors.report_resolve'.tr(), error: true);
    }
  }

  Future<void> _forceClose(dynamic id, String name) async {
    if (!await _showConfirm(context,
        '¿Cerrar definitivamente la sala "$name"?\n\nLos usuarios serán expulsados y la sala quedará desactivada. Los datos se conservan.'))
      return;
    final auth = await widget.getAuthHeader();
    final res = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/admin/rooms/$id'),
      headers: {'Authorization': auth},
    );
    if (mounted) {
      _snack(res.statusCode == 200
          ? 'Sala cerrada correctamente'
          : jsonDecode(res.body)['error'] ?? 'Error',
          error: res.statusCode != 200);
    }
    _load();
  }

  Future<void> _kickAll(dynamic id, String name) async {
    if (!await _showConfirm(context,
        '¿Echar a todos los usuarios de "$name"?\n\nLa sala seguirá activa y podrán volver a entrar.'))
      return;
    final auth = await widget.getAuthHeader();
    final res = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/admin/rooms/$id/kick-all'),
      headers: {'Authorization': auth},
    );
    if (mounted) {
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _snack(data['message'] ?? 'Usuarios echados');
      } else {
        _snack(jsonDecode(res.body)['error'] ?? 'Error', error: true);
      }
    }
    _load();
  }

  /// Marcar incidencia: muestra diálogo rico con nota + opciones de acción.
  /// Retirar incidencia: confirmación simple.
  Future<void> _toggleFlag(dynamic room) async {
    final id         = room['id'];
    final name       = room['name']    as String? ?? '—';
    final isFlagged  = room['flagged'] == true;
    final isActive   = room['active']  == true;
    final online     = (room['onlineUserCount'] as int?) ?? 0;

    if (isFlagged) {
      // ── Retirar incidencia ──────────────────────────────────────────────
      if (!await _showConfirm(context,
          '¿Retirar la marca de incidencia de "$name"?\n\nLa nota de incidencia también se borrará.')) return;
      final auth = await widget.getAuthHeader();
      final res  = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/admin/rooms/$id/flag'),
        headers: {'Content-Type': 'application/json', 'Authorization': auth},
        body: jsonEncode({}),
      );
      if (mounted) {
        _snack(res.statusCode == 200
            ? (jsonDecode(res.body)['message'] ?? 'Incidencia retirada')
            : (jsonDecode(res.body)['error']   ?? 'Error'),
            error: res.statusCode != 200);
      }
    } else {
      // ── Marcar incidencia: diálogo rico ────────────────────────────────
      final result = await _showFlagDialog(
        context,
        roomName:  name,
        isActive:  isActive,
        onlineCount: online,
      );
      if (result == null) return; // cancelado
      final auth = await widget.getAuthHeader();
      final res  = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/admin/rooms/$id/flag'),
        headers: {'Content-Type': 'application/json', 'Authorization': auth},
        body: jsonEncode({
          'reason':    result.reason,
          'kickAll':   result.kickAll,
          'closeRoom': result.closeRoom,
        }),
      );
      if (mounted) {
        if (res.statusCode == 200) {
          final data    = jsonDecode(res.body);
          final kicked  = data['kicked'] as int?;
          var msg       = data['message'] ?? 'Sala marcada';
          if (kicked != null && kicked > 0) msg += ' · $kicked usuarios echados';
          _snack(msg);
        } else {
          _snack(jsonDecode(res.body)['error'] ?? 'Error', error: true);
        }
      }
    }
    _load();
  }

  /// Editar solo la nota de una sala ya flaggeada.
  Future<void> _editFlagReason(dynamic room) async {
    final id          = room['id'];
    final currentNote = room['flagReason'] as String? ?? '';
    final ctrl        = TextEditingController(text: currentNote);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.edit_report_note'.tr()),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'admin.report_reason_hint'.tr(),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    final newReason = ctrl.text.trim();
    ctrl.dispose();
    if (saved != true || !mounted) return;

    final auth = await widget.getAuthHeader();
    final res  = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/admin/rooms/$id/flag/reason'),
      headers: {'Content-Type': 'application/json', 'Authorization': auth},
      body: jsonEncode({'reason': newReason}),
    );
    if (mounted) {
      _snack(res.statusCode == 200 ? 'Nota actualizada' : 'Error al guardar',
             error: res.statusCode != 200);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered      = _filtered;
    final pendingTotal  = _reports.where((r) => r['resolved'] != true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Gestión de salas',
          subtitle: pendingTotal > 0
              ? '${_rooms.length} salas · $pendingTotal reportes pendientes'
              : '${_rooms.length} salas totales',
          icon: Icons.meeting_room,
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'common.reload'.tr(),
            onPressed: _load,
          ),
        ),
        // ── Buscador ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'admin.search_rooms_hint'.tr(),
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        // ── Filtros ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _FilterChip(label: 'Todas',        selected: _filter == _RoomFilter.all,     onTap: () => setState(() => _filter = _RoomFilter.all)),
              _FilterChip(label: 'Activas',      selected: _filter == _RoomFilter.active,  onTap: () => setState(() => _filter = _RoomFilter.active),  color: Colors.green),
              _FilterChip(label: 'Cerradas',     selected: _filter == _RoomFilter.closed,  onTap: () => setState(() => _filter = _RoomFilter.closed),  color: Colors.grey),
              _FilterChip(label: '⚑ Incidencia', selected: _filter == _RoomFilter.flagged, onTap: () => setState(() => _filter = _RoomFilter.flagged), color: Colors.orange),
              _FilterChip(
                label: '⚠ Con reportes',
                selected: _filterReports,
                onTap: () => setState(() => _filterReports = !_filterReports),
                color: Colors.red,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Lista ─────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? _Empty(icon: Icons.meeting_room_outlined, text: 'No hay salas con este filtro')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                        itemBuilder: (_, i) {
                          final r = filtered[i];
                          return _RoomCard(
                            room:             r,
                            reports:          _reportsForRoom(r['id']),
                            onClose:          () => _forceClose(r['id'], r['name']),
                            onKickAll:        () => _kickAll(r['id'], r['name']),
                            onToggleFlag:     () => _toggleFlag(r),
                            onEditNote:       () => _editFlagReason(r),
                            onEnter:          () => _enterRoom(context, r),
                            onResolveReport:  (rid) => _resolveReport(rid),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  /// El admin entra a la sala directamente desde el panel.
  /// Abre el RoomScreen como una ruta encima del admin panel,
  /// de forma que al salir de la sala vuelve al panel (no a HomeScreen).
  Future<void> _enterRoom(BuildContext ctx, dynamic roomData) async {
    final id   = roomData['id'];
    final name = roomData['name'] as String? ?? '—';

    try {
      final auth = await widget.getAuthHeader();
      final res  = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/admin/rooms/$id'),
        headers: {'Authorization': auth},
      );
      if (res.statusCode != 200) {
        _snack('No se pudo obtener la sala', error: true);
        return;
      }
      if (!ctx.mounted) return;
      final room = Room.fromJson(jsonDecode(res.body));
      await Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => RoomScreen(room: room)),
      );
    } catch (_) {
      _snack('Error al entrar en "$name"', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }
}

// ── Tarjeta de sala expandible ───────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  final dynamic room;
  final List<dynamic> reports;
  final VoidCallback onClose;
  final VoidCallback onKickAll;
  final VoidCallback onToggleFlag;
  final VoidCallback onEditNote;
  final VoidCallback onEnter;
  final void Function(dynamic reportId) onResolveReport;

  const _RoomCard({
    required this.room,
    required this.reports,
    required this.onClose,
    required this.onKickAll,
    required this.onToggleFlag,
    required this.onEditNote,
    required this.onEnter,
    required this.onResolveReport,
  });

  @override
  Widget build(BuildContext context) {
    final active         = room['active']          == true;
    final flagged        = room['flagged']          == true;
    final online         = (room['onlineUserCount'] as int?) ?? 0;
    final privacy        = room['privacy']          as String? ?? '';
    final host           = room['hostUsername']     as String? ?? '?';
    final name           = room['name']             as String? ?? '—';
    final genres         = (room['genres']          as List?)?.cast<String>() ?? [];
    final flagReason     = room['flagReason']        as String?;
    final pendingReports = reports.where((r) => r['resolved'] != true).toList();

    return ExpansionTile(
      leading: SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            _statusDot(active, flagged),
            if (pendingReports.isNotEmpty)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${pendingReports.length}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (flagged)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.flag, color: Colors.orange, size: 16),
            ),
        ],
      ),
      subtitle: Text(
        'admin.room_host'.tr(namedArgs: {'host': host, 'privacy': privacy}) +
            (active
                ? '  ·  ${'admin.room_online'.tr(namedArgs: {'n': '$online'})}'
                : '  ·  ${'admin.room_closed'.tr()}'),
        style: const TextStyle(fontSize: 12),
      ),
      // ── Detalle expandido ──────────────────────────────────────────────
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (genres.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  children: genres
                      .map((g) => Chip(
                            label: Text(g, style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 6),
              ],
              if (room['description'] != null && (room['description'] as String).isNotEmpty)
                Text(
                  room['description'],
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),

              // ── Nota de incidencia ───────────────────────────────────────
              if (flagged) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.flag, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          flagReason != null && flagReason.isNotEmpty
                              ? flagReason
                              : 'Sin nota de incidencia',
                          style: TextStyle(
                            fontSize: 12,
                            color: flagReason != null && flagReason.isNotEmpty
                                ? Colors.orange.shade900
                                : Colors.orange.shade400,
                            fontStyle: flagReason == null || flagReason.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              // ── Botones de acción ────────────────────────────────────────
              OverflowBar(
                spacing: 8,
                children: [
                  // Echar usuarios — solo si está activa y hay alguien
                  if (active)
                    OutlinedButton.icon(
                      onPressed: online > 0 ? onKickAll : null,
                      icon: const Icon(Icons.logout, size: 16),
                      label: Text('admin.kick_users_n'.tr(namedArgs: {'n': '$online'})),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                    ),
                  // Editar nota — solo si ya está flaggeada
                  if (flagged)
                    OutlinedButton.icon(
                      onPressed: onEditNote,
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: Text(flagReason != null && flagReason.isNotEmpty
                          ? 'Editar nota'
                          : 'Añadir nota'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800),
                    ),
                  // Marcar / desmarcar incidencia
                  OutlinedButton.icon(
                    onPressed: onToggleFlag,
                    icon: Icon(
                      flagged ? Icons.flag_outlined : Icons.flag,
                      size: 16,
                      color: flagged ? Colors.grey : Colors.orange,
                    ),
                    label: Text(flagged ? 'Retirar incidencia' : 'admin.flag_report'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: flagged ? Colors.grey : Colors.orange,
                    ),
                  ),
                  // Entrar a sala — solo si está activa
                  if (active)
                    OutlinedButton.icon(
                      onPressed: onEnter,
                      icon: const Icon(Icons.login_rounded, size: 16),
                      label: Text('admin.enter_room'.tr()),
                    ),
                  // Cerrar sala — solo si está activa
                  if (active)
                    FilledButton.icon(
                      onPressed: onClose,
                      icon: const Icon(Icons.close, size: 16),
                      label: Text('rooms.close_button'.tr()),
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Reportes de usuarios ─────────────────────────────────────
              if (reports.isNotEmpty) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    Icon(Icons.report_outlined,
                        size: 13,
                        color: pendingReports.isNotEmpty ? Colors.red.shade600 : Colors.grey),
                    const SizedBox(width: 5),
                    Text(
                      pendingReports.isNotEmpty
                          ? '${pendingReports.length} reporte${pendingReports.length > 1 ? 's' : ''} pendiente${pendingReports.length > 1 ? 's' : ''}'
                          : 'Todos los reportes resueltos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pendingReports.isNotEmpty ? Colors.red.shade600 : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...reports.map((r) {
                  final resolved  = r['resolved'] == true;
                  final reporter  = r['reporterUsername'] as String? ?? '?';
                  final reason    = r['reason']           as String? ?? '';
                  final createdAt = r['createdAt']        as String? ?? '';
                  final bgColor     = resolved ? Colors.grey.shade100  : Colors.red.shade50;
                  final borderColor = resolved ? Colors.grey.shade300  : Colors.red.shade300;
                  final metaColor   = resolved ? Colors.grey.shade500  : Colors.red.shade700;
                  final textColor   = resolved ? Colors.grey.shade700  : Colors.grey.shade900;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@$reporter · ${_fmtDate(createdAt)}',
                                style: TextStyle(fontSize: 11, color: metaColor,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 3),
                              Text(reason,
                                  style: TextStyle(fontSize: 12.5, color: textColor,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (!resolved)
                          FilledButton(
                            onPressed: () => onResolveReport(r['id']),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              minimumSize: const Size(64, 28),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: Text('admin.resolve'.tr()),
                          )
                        else
                          Icon(Icons.check_circle_rounded, size: 18, color: Colors.green.shade600),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _fmtDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return raw;
    }
  }

  Widget _statusDot(bool active, bool flagged) {
    final color = flagged
        ? Colors.orange
        : active
            ? Colors.green
            : Colors.grey;
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// USUARIOS
// ════════════════════════════════════════════════════════════════════════════

class _UsersPage extends StatefulWidget {
  final Future<String> Function() getAuthHeader;
  const _UsersPage({required this.getAuthHeader});

  @override
  State<_UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<_UsersPage> {
  List<dynamic> _users = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final auth = await widget.getAuthHeader();
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/admin/users'),
        headers: {'Authorization': auth},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _users = jsonDecode(res.body));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    if (_search.isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users.where((u) =>
        (u['username'] as String).toLowerCase().contains(q) ||
        (u['email']    as String).toLowerCase().contains(q)).toList();
  }

  Future<void> _changeRole(String username, String currentRole) async {
    final newRole = currentRole == 'ADMIN' ? 'USER' : 'ADMIN';
    if (!await _showConfirm(context, '¿Cambiar rol de "$username" a $newRole?')) return;
    final auth = await widget.getAuthHeader();
    final res = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/admin/users/$username/role'),
      headers: {'Content-Type': 'application/json', 'Authorization': auth},
      body: jsonEncode({'role': newRole}),
    );
    if (mounted) {
      if (res.statusCode == 200) {
        _snack('Rol de $username actualizado a $newRole');
        _load();
      } else {
        _snack(jsonDecode(res.body)['error'] ?? 'Error', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Gestión de usuarios',
          subtitle: '${_users.length} usuarios registrados',
          icon: Icons.people,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'admin.search_users_hint'.tr(),
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? _Empty(icon: Icons.person_off, text: 'No se encontraron usuarios')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                        itemBuilder: (_, i) {
                          final u    = filtered[i];
                          final role = u['role'] as String? ?? 'USER';
                          final isAdmin = role == 'ADMIN';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAdmin
                                  ? Colors.deepPurple.shade100
                                  : Colors.grey.shade200,
                              child: Text(
                                (u['username'] as String)[0].toUpperCase(),
                                style: TextStyle(
                                  color: isAdmin ? Colors.deepPurple : Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(u['username']),
                            subtitle: Text(u['email'] ?? ''),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(role, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: isAdmin
                                      ? Colors.deepPurple.shade100
                                      : Colors.grey.shade200,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(
                                    isAdmin ? Icons.arrow_downward : Icons.arrow_upward,
                                    size: 18,
                                    color: isAdmin ? Colors.orange : Colors.deepPurple,
                                  ),
                                  tooltip: isAdmin ? 'Quitar admin' : 'Hacer admin',
                                  onPressed: () => _changeRole(u['username'], role),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }
}



// ════════════════════════════════════════════════════════════════════════════
// WIDGETS COMUNES
// ════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
        border: Border(bottom: BorderSide(color: appDivider)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: c.withOpacity(0.15),
      checkmarkColor: c,
      labelStyle: TextStyle(
        color: selected ? c : null,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

// ── Helper global de confirmación ────────────────────────────────────────────

Future<bool> _showConfirm(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('common.confirm'.tr()),
            ),
          ],
        ),
      ) ??
      false;
}

// ── Resultado del diálogo de marcar incidencia ────────────────────────────────

class _FlagResult {
  final String reason;
  final bool kickAll;
  final bool closeRoom;
  const _FlagResult({required this.reason, required this.kickAll, required this.closeRoom});
}

// ── Diálogo para marcar una sala como incidencia ──────────────────────────────

Future<_FlagResult?> _showFlagDialog(
  BuildContext context, {
  required String roomName,
  required bool isActive,
  required int onlineCount,
}) async {
  final reasonCtrl = TextEditingController();
  bool kickAll   = isActive && onlineCount > 0;
  bool closeRoom = false;

  final result = await showDialog<_FlagResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.flag, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text('admin.flag_report'.tr()),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'admin.room_named'.tr(namedArgs: {'room': roomName}),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'admin.close_room_note'.tr(),
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              // Nota
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'admin.report_note_label'.tr(),
                  hintText: 'admin.report_note_hint'.tr(),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              // Opciones adicionales (solo si la sala está activa)
              if (isActive) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'admin.kick_online_n'.tr(namedArgs: {'n': '$onlineCount'}),
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: kickAll,
                  onChanged: onlineCount > 0
                      ? (v) => setState(() => kickAll = v ?? false)
                      : null,
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'admin.close_room_forever'.tr(),
                    style: TextStyle(fontSize: 13),
                  ),
                  value: closeRoom,
                  onChanged: (v) => setState(() => closeRoom = v ?? false),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(
              ctx,
              _FlagResult(
                reason:    reasonCtrl.text.trim(),
                kickAll:   kickAll,
                closeRoom: closeRoom,
              ),
            ),
            child: Text('admin.flag_report'.tr()),
          ),
        ],
      ),
    ),
  );

  reasonCtrl.dispose();
  return result;
}
