import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import 'package:viber/core/widgets/motion.dart';
import 'package:viber/core/widgets/user_avatar.dart';
import '../infrastructure/friendship_service.dart';
import '../infrastructure/stats_service.dart';
import '../domain/user_profile.dart';
import '../domain/user_stats.dart';
import 'edit_profile_screen.dart';
import 'friends_screen.dart';
import 'liked_songs_screen.dart';
import 'settings_screen.dart';

/// Pantalla de perfil de usuario.
/// Si [username] es null muestra el perfil propio con acceso a edición y estadísticas.
/// Si tiene valor muestra el perfil ajeno con acciones sociales.
class ProfileScreen extends StatefulWidget {
  final String? username;
  final VoidCallback? onLogout;
  const ProfileScreen({super.key, this.username, this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _friendService = FriendshipService();
  final _statsService  = StatsService();

  UserProfile? _profile;
  UserStats?   _stats;
  bool    _loading      = true;
  bool    _loadingStats = false;
  String? _error;

  bool get _isOwn => widget.username == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = _isOwn
          ? await _friendService.getMe()
          : await _friendService.getProfile(widget.username!);
      if (mounted) setState(() => _profile = p);
      _loadStats(p.username);
    } catch (e) {
      if (mounted) setState(() =>
          _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStats(String username) async {
    if (mounted) setState(() => _loadingStats = true);
    try {
      final s = _isOwn
          ? await _statsService.getMyStats()
          : await _statsService.getUserStats(username);
      if (mounted) setState(() => _stats = s);
    } catch (_) {
      // stats son opcionales — silenciar error
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _sendRequest() async {
    try {
      await _friendService.sendRequest(_profile!.username);
      await _load();
      if (mounted) AppSnackBar.show(context, 'Solicitud enviada');
    } catch (e) {
      if (mounted) AppSnackBar.show(context,
          e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Future<void> _removeFriend() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminar amigo',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('¿Eliminar a ${_profile!.username}?',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: appError))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _friendService.removeFriend(_profile!.username);
      await _load();
    } catch (e) {
      if (mounted) AppSnackBar.show(context,
          e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.displayLabel ?? 'Perfil'),
        actions: [
          // Botón de refresh (útil en web donde pull-to-refresh no funciona)
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: appAccent),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
          ),
          if (_isOwn && widget.onLogout != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Ajustes',
              onPressed: _profile == null
                  ? null
                  : () => Navigator.push(
                        context,
                        fadeThroughRoute(
                            SettingsScreen(onLogout: widget.onLogout!)),
                      ),
            ),
        ],
      ),
      body: _loading
          ? const _ProfileSkeleton()
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: appError)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final p = _profile!;
    return RefreshIndicator(
      onRefresh: _load,
      color: appAccent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
            horizontal: spacingXl, vertical: spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + stats row ─────────────────────────────────────
            AppEntrance(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UserAvatar(
                    username: p.username, avatarUrl: p.avatarUrl, radius: 44),
                const SizedBox(width: spacingXl),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat(
                        value: '${p.friendCount}',
                        label: 'Amigos',
                        onTap: _isOwn
                            ? () => Navigator.push(context,
                                fadeThroughRoute(const FriendsScreen()))
                            : null,
                      ),
                      if (_stats != null) ...[
                        _Stat(
                          value: '${_stats!.roomsCreated}',
                          label: 'Salas creadas',
                        ),
                        _Stat(
                          value: '${_stats!.likedSongsCount}',
                          label: 'Favoritas',
                          onTap: _isOwn
                              ? () => Navigator.push(context,
                                  fadeThroughRoute(const LikedSongsScreen()))
                              : null,
                        ),
                      ] else if (_loadingStats)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: appAccent),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            ),

            const SizedBox(height: spacingLg),

            // ── Name & bio ────────────────────────────────────────────
            Text(
              p.displayLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (p.displayName != null && p.displayName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '@${p.username}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13),
              ),
            ],
            if (p.bio != null && p.bio!.isNotEmpty) ...[
              const SizedBox(height: spacingXs),
              Text(
                p.bio!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
            if (p.createdAt != null) ...[
              const SizedBox(height: spacingXs),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                      size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'En Viber desde ${_formatDate(p.createdAt!)}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                        fontSize: 11),
                  ),
                ],
              ),
            ],

            const SizedBox(height: spacingXl),
            AppEntrance(
              delay: const Duration(milliseconds: 90),
              child: _buildActions(p),
            ),

            // ── Estadísticas detalladas ────────────────────────────────
            if (_stats != null) ...[
              const SizedBox(height: spacingXl),
              AppEntrance(
                delay: const Duration(milliseconds: 150),
                child: _buildStatsCard(_stats!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Stats card ─────────────────────────────────────────────────────────────

  Widget _buildStatsCard(UserStats stats) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appDivider),
      ),
      padding: const EdgeInsets.all(spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadísticas',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: spacingMd),

          // ── Fila 1: tiempo + salas ──────────────────────────────────
          Row(
            children: [
              Expanded(child: _StatRow(
                icon: Icons.headphones_rounded,
                label: 'Tiempo escuchado',
                value: stats.listenTimeFormatted,
              )),
              Expanded(child: _StatRow(
                icon: Icons.meeting_room_outlined,
                label: 'Salas unidas',
                value: '${stats.roomsJoined}',
              )),
            ],
          ),
          const SizedBox(height: spacingMd),

          // ── Fila 2: canciones ───────────────────────────────────────
          Row(
            children: [
              Expanded(child: _StatRow(
                icon: Icons.queue_music_rounded,
                label: 'Canciones añadidas',
                value: '${stats.songsAdded}',
              )),
              Expanded(child: _StatRow(
                icon: Icons.headset_rounded,
                label: 'Canciones escuchadas',
                value: '${stats.songsPlayed}',
              )),
            ],
          ),
          const SizedBox(height: spacingMd),

          // ── Fila 3: favoritas ───────────────────────────────────────
          Row(
            children: [
              Expanded(child: _StatRow(
                icon: Icons.favorite_rounded,
                label: 'Favoritas',
                value: '${stats.likedSongsCount}',
              )),
              const Expanded(child: SizedBox()),
            ],
          ),

          // ── Géneros más escuchados ──────────────────────────────────
          const SizedBox(height: spacingLg),
          _BarChartSection(
            title: 'Géneros más escuchados',
            entries: stats.topGenres,
            emptyLabel: 'Únete a salas para ver tus géneros',
            tooltipSuffix: (n) => n == 1 ? 'sala' : 'salas',
          ),

          // ── Artistas más escuchados ─────────────────────────────────
          const SizedBox(height: spacingLg),
          _BarChartSection(
            title: 'Artistas más escuchados',
            entries: stats.topArtists,
            emptyLabel: 'Escucha canciones en salas para ver tus artistas',
            tooltipSuffix: (n) => n == 1 ? 'reproducción' : 'reproducciones',
          ),
        ],
      ),
    );
  }

  // ── Action buttons ─────────────────────────────────────────────────────────

  Widget _buildActions(UserProfile p) {
    if (_isOwn) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar perfil'),
              onPressed: () async {
                final updated = await Navigator.push<UserProfile>(
                  context,
                  fadeThroughRoute<UserProfile>(EditProfileScreen(profile: p)),
                );
                if (updated != null && mounted) {
                  setState(() => _profile = updated);
                }
              },
            ),
          ),
          const SizedBox(width: spacingMd),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.group_outlined, size: 16),
              label: const Text('Amigos'),
              onPressed: () => Navigator.push(
                context,
                fadeThroughRoute(const FriendsScreen()),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: switch (p.relation) {
        'FRIENDS' => OutlinedButton.icon(
            icon: const Icon(Icons.person_remove_outlined, size: 16),
            label: const Text('Eliminar amigo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: appError,
              side: const BorderSide(color: appError),
            ),
            onPressed: _removeFriend,
          ),
        'PENDING_SENT' => OutlinedButton.icon(
            icon: const Icon(Icons.hourglass_top_rounded, size: 16),
            label: const Text('Solicitud enviada'),
            onPressed: null,
          ),
        'PENDING_RECEIVED' => ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Aceptar solicitud'),
            onPressed: () async {
              await _friendService.acceptRequest(p.username);
              await _load();
            },
          ),
        _ => ElevatedButton.icon(
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Añadir amigo'),
            onPressed: _sendRequest,
          ),
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Stat widget (header row) ───────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  const _Stat({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: appAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: appAccent.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Fila de stat dentro de la card ────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 16,
            color: context.appTextSecColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: content,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: content,
    );
  }
}

// ── Sección de gráfico de barras (géneros o artistas) ─────────────────────────

class _BarChartSection extends StatelessWidget {
  final String title;
  final List<GenreStat> entries;
  final String emptyLabel;
  final String Function(int count) tooltipSuffix;

  const _BarChartSection({
    required this.title,
    required this.entries,
    required this.emptyLabel,
    required this.tooltipSuffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Text(
            emptyLabel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          _BarChart(entries: entries, tooltipSuffix: tooltipSuffix),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<GenreStat> entries;
  final String Function(int count) tooltipSuffix;

  const _BarChart({required this.entries, required this.tooltipSuffix});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final maxCount = entries.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return Column(
      children: entries.asMap().entries.map((entry) {
        final i = entry.key;
        final g = entry.value;
        final fraction = maxCount > 0 ? (g.count / maxCount).clamp(0.0, 1.0) : 0.0;
        final opacity = (1.0 - i * 0.14).clamp(0.45, 1.0);
        final barColor = appAccent.withValues(alpha: opacity);
        final tooltipMsg = '${g.name} — ${g.count} ${tooltipSuffix(g.count)}';

        return Tooltip(
          message: tooltipMsg,
          waitDuration: const Duration(milliseconds: 250),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Etiqueta (ancho fijo)
                SizedBox(
                  width: 80,
                  child: Text(
                    g.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight:
                          i == 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // Barra (ocupa todo el espacio restante)
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Track de fondo
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: appAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      // Barra rellena proporcional — crece al aparecer, con
                      // un leve desfase por fila para un efecto en cascada.
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: fraction),
                        duration: Duration(milliseconds: 550 + i * 90),
                        curve: Curves.easeOutCubic,
                        builder: (_, w, _) => FractionallySizedBox(
                          widthFactor: w,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: i == 0
                                  ? [
                                      BoxShadow(
                                        color: appAccent.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Contador (ancho fijo para alineación)
                SizedBox(
                  width: 26,
                  child: Text(
                    '${g.count}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Skeleton de carga ─────────────────────────────────────────────────────────

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  Widget _miniStat() => Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          ShimmerBox(width: 30, height: 18),
          SizedBox(height: 7),
          ShimmerBox(width: 46, height: 10),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
          horizontal: spacingXl, vertical: spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(
                  width: 88, height: 88, borderRadius: BorderRadius.circular(44)),
              const SizedBox(width: spacingXl),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_miniStat(), _miniStat(), _miniStat()],
                ),
              ),
            ],
          ),
          const SizedBox(height: spacingLg),
          const ShimmerBox(width: 160, height: 16),
          const SizedBox(height: 10),
          const ShimmerBox(width: 220, height: 12),
          const SizedBox(height: spacingXl),
          ShimmerBox(
              width: double.infinity,
              height: 44,
              borderRadius: BorderRadius.circular(radiusMd)),
          const SizedBox(height: spacingXl),
          ShimmerBox(
              width: double.infinity,
              height: 200,
              borderRadius: BorderRadius.circular(radiusLg)),
        ],
      ),
    );
  }
}
