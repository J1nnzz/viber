import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import '../../rooms/domain/room_message.dart';
import '../infrastructure/youtube_service.dart';
import '../domain/youtube_result.dart';
import '../../rooms/infrastructure/room_websocket_service.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_image.dart';

// ── Punto de entrada: menú contextual ─────────────────────────────────────────

enum _AddChoice { search, playlist }

/// Muestra el menú "Añadir +" y, según la elección, abre el sheet
/// correspondiente. Devuelve un Future que completa cuando el último modal
/// (incluido el anidado) se cierra — úsalo con .whenComplete() para
/// re-habilitar los pointer-events del iframe.
Future<void> showAddMenu({
  required BuildContext context,
  required RoomWebSocketService wsService,
  required String username,
}) async {
  final choice = await showModalBottomSheet<_AddChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddMenuSheet(wsService: wsService, username: username),
  );

  if (choice == null || !context.mounted) return;

  if (choice == _AddChoice.search) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchSongSheet(wsService: wsService, username: username),
    );
  } else if (choice == _AddChoice.playlist) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ImportPlaylistSheet(wsService: wsService, username: username),
    );
  }
}

class _AddMenuSheet extends StatelessWidget {
  final RoomWebSocketService wsService;
  final String username;

  const _AddMenuSheet({required this.wsService, required this.username});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusXl)),
        border: Border(top: BorderSide(color: appDivider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.appDividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'youtube.add_to_queue'.tr(),
                  style: TextStyle(
                    color: context.appTextPrimColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: appDivider),
            // Opción: canción
            _MenuOption(
              icon: Icons.music_note_rounded,
              label: 'youtube.search_song'.tr(),
              subtitle: 'youtube.search_by'.tr(),
              onTap: () => Navigator.pop(context, _AddChoice.search),
            ),
            Divider(height: 1, color: appDivider, indent: 56),
            // Opción: playlist
            _MenuOption(
              icon: Icons.queue_music_rounded,
              label: 'Importar playlist',
              subtitle: 'youtube.paste_url'.tr(),
              onTap: () => Navigator.pop(context, _AddChoice.playlist),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: appAccentGlow,
                borderRadius: BorderRadius.circular(radiusSm),
              ),
              child: Icon(icon, color: appAccent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(
                      color: context.appTextPrimColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: TextStyle(color: context.appTextSecColor, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.appTextSecColor, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Sheet: Buscar canción ──────────────────────────────────────────────────────

class SearchSongSheet extends StatefulWidget {
  final RoomWebSocketService wsService;
  final String username;

  const SearchSongSheet({
    super.key,
    required this.wsService,
    required this.username,
  });

  @override
  State<SearchSongSheet> createState() => _SearchSongSheetState();
}

class _SearchSongSheetState extends State<SearchSongSheet> {
  final _searchController = TextEditingController();
  final _youtubeService   = YoutubeService();

  List<YoutubeSearchResult> _results = [];
  bool    _loading = false;
  String? _error;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;
    setState(() { _loading = true; _error = null; _results = []; });
    try {
      final results = await _youtubeService.search(query);
      setState(() => _results = results);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _addToQueue(YoutubeSearchResult result) {
    widget.wsService.sendMessage(RoomMessage(
      type:           RoomMessage.queueAdd,
      senderUsername: widget.username,
      videoId:        result.videoId,
      videoTitle:     result.title,
      videoThumbnail: result.thumbnail,
      videoChannel:   result.channel.isNotEmpty ? result.channel : null,
    ));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.queue_music_rounded, color: appAccent, size: 16),
        const SizedBox(width: spacingSm),
        Expanded(child: Text('youtube.added_to_queue'.tr(namedArgs: {'title': '${result.title}'}),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      duration: const Duration(seconds: 2),
    ));
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusXl)),
        border: Border(top: BorderSide(color: appDivider)),
      ),
      child: Column(
        children: [
          _buildHandle(context),
          _buildHeader(context, 'youtube.search_song'.tr(), Icons.search_rounded),
          Divider(height: 1, color: appDivider),
          // Buscador
          Padding(
            padding: const EdgeInsets.all(spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(color: context.appTextPrimColor),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'youtube.search_hint'.tr(),
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: spacingSm),
                ElevatedButton.icon(
                  icon: _loading
                    ? SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: context.appTextPrimColor))
                    : const Icon(Icons.search_rounded, size: 16),
                  label: Text(_loading ? 'Buscando...' : 'Buscar'),
                  onPressed: _loading ? null : _search,
                ),
              ],
            ),
          ),
          // Resultados
          Expanded(
            child: _error != null
              ? Center(child: AppErrorBanner(message: _error!))
              : _results.isEmpty && !_loading
                ? _buildEmptyHint(context, 'youtube.search_empty'.tr())
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: appDivider),
                    itemBuilder: (ctx, i) {
                      final r = _results[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: spacingMd, vertical: spacingXs),
                        leading: _thumb(ctx, r.thumbnail),
                        title: Text(r.title,
                          style: TextStyle(color: ctx.appTextPrimColor, fontSize: 13),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(r.channel,
                          style: TextStyle(color: ctx.appTextSecColor, fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_rounded,
                            color: appAccent, size: 28),
                          tooltip: 'youtube.add_to_queue'.tr(),
                          onPressed: () => _addToQueue(r),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet: Importar playlist ───────────────────────────────────────────────────

class ImportPlaylistSheet extends StatefulWidget {
  final RoomWebSocketService wsService;
  final String username;

  const ImportPlaylistSheet({
    super.key,
    required this.wsService,
    required this.username,
  });

  @override
  State<ImportPlaylistSheet> createState() => _ImportPlaylistSheetState();
}

class _ImportPlaylistSheetState extends State<ImportPlaylistSheet> {
  final _urlController   = TextEditingController();
  final _youtubeService  = YoutubeService();

  // ── Estados del flujo ──────────────────────────────────────────────────────
  // idle → loading → preview → importing → done
  _PlaylistFlowState _flowState = _PlaylistFlowState.idle;

  List<YoutubeSearchResult> _tracks  = [];
  // Selección por videoId — inmune a cambios de posición/scroll del ListView
  final Set<String> _selectedIds = {};
  String? _error;

  // ── Acciones ───────────────────────────────────────────────────────────────

  Future<void> _fetchPlaylist() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() { _flowState = _PlaylistFlowState.loading; _error = null; });

    try {
      final tracks = await _youtubeService.fetchPlaylist(url);
      setState(() {
        _tracks = tracks;
        _selectedIds
          ..clear()
          ..addAll(tracks.map((t) => t.videoId));
        _flowState = _PlaylistFlowState.preview;
      });
    } catch (e) {
      setState(() {
        _error     = e.toString().replaceAll('Exception: ', '');
        _flowState = _PlaylistFlowState.idle;
      });
    }
  }

  void _importSelected() {
    // Snapshot de los tracks seleccionados en el momento de pulsar "Añadir"
    final toImport = _tracks
        .where((t) => _selectedIds.contains(t.videoId))
        .toList();
    if (toImport.isEmpty) return;

    setState(() => _flowState = _PlaylistFlowState.importing);

    // Ráfaga de QUEUE_ADD — el servidor los procesa en orden
    for (final track in toImport) {
      widget.wsService.sendMessage(RoomMessage(
        type:           RoomMessage.queueAdd,
        senderUsername: widget.username,
        videoId:        track.videoId,
        videoTitle:     track.title,
        videoThumbnail: track.thumbnail,
        videoChannel:   track.channel.isNotEmpty ? track.channel : null,
      ));
    }

    setState(() => _flowState = _PlaylistFlowState.done);
  }

  void _reset() => setState(() {
    _flowState = _PlaylistFlowState.idle;
    _tracks    = [];
    _selectedIds.clear();
    _error     = null;
    _urlController.clear();
  });

  int get _selectedCount => _selectedIds.length;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusXl)),
        border: Border(top: BorderSide(color: appDivider)),
      ),
      child: Column(
        children: [
          _buildHandle(context),
          _buildHeader(context, 'Importar playlist', Icons.queue_music_rounded),
          Divider(height: 1, color: appDivider),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return switch (_flowState) {
      _PlaylistFlowState.idle     => _buildUrlInput(),
      _PlaylistFlowState.loading  => _buildLoading(),
      _PlaylistFlowState.preview  => _buildPreview(),
      _PlaylistFlowState.importing => _buildImporting(),
      _PlaylistFlowState.done     => _buildDone(),
    };
  }

  // ── Paso 1: Pegar URL ──────────────────────────────────────────────────────

  Widget _buildUrlInput() {
    return Padding(
      padding: const EdgeInsets.all(spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instrucción
          Container(
            padding: const EdgeInsets.all(spacingMd),
            decoration: BoxDecoration(
              color: appAccentGlow,
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                  color: appAccent, size: 16),
                const SizedBox(width: spacingSm),
                Expanded(
                  child: Text(
                    'youtube.playlist_help'.tr(),
                    style: TextStyle(color: context.appTextSecColor, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: spacingLg),
          // Campo URL
          TextField(
            controller: _urlController,
            autofocus: true,
            style: TextStyle(color: context.appTextPrimColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'https://www.youtube.com/playlist?list=PL...',
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: IconButton(
                icon: Icon(Icons.content_paste_rounded,
                  color: context.appTextSecColor, size: 18),
                tooltip: 'youtube.paste_clipboard'.tr(),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _urlController.text = data!.text!;
                  }
                },
              ),
            ),
            onSubmitted: (_) => _fetchPlaylist(),
          ),
          if (_error != null) ...[
            const SizedBox(height: spacingMd),
            AppErrorBanner(message: _error!),
          ],
          const Spacer(),
          // Botón
          ElevatedButton.icon(
            icon: const Icon(Icons.search_rounded, size: 18),
            label: Text('youtube.load_playlist'.tr()),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _fetchPlaylist,
          ),
        ],
      ),
    );
  }

  // ── Paso 2: Cargando ───────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: appAccent),
          const SizedBox(height: spacingMd),
          Text('youtube.loading_playlist'.tr(),
            style: TextStyle(color: context.appTextSecColor, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Paso 3: Preview con selección ─────────────────────────────────────────

  Widget _buildPreview() {
    final allSelected = _selectedIds.length == _tracks.length;

    return Column(
      children: [
        // Barra de acciones
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: spacingMd, vertical: spacingSm),
          child: Row(
            children: [
              Text('youtube.tracks_found'.tr(namedArgs: {'n': '${_tracks.length}'}),
                style: TextStyle(color: context.appTextSecColor, fontSize: 12)),
              const Spacer(),
              // Seleccionar/deseleccionar todo
              TextButton(
                onPressed: () => setState(() {
                  if (allSelected) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(_tracks.map((t) => t.videoId));
                  }
                }),
                child: Text(
                  allSelected ? 'Deseleccionar todo' : 'Seleccionar todo',
                  style: const TextStyle(color: appAccent, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: appDivider),
        // Lista
        Expanded(
          child: ListView.separated(
            itemCount: _tracks.length,
            separatorBuilder: (_, __) =>
              Divider(height: 1, color: appDivider),
            itemBuilder: (ctx, i) {
              final t = _tracks[i];
              final isSelected = _selectedIds.contains(t.videoId);
              return CheckboxListTile(
                key: ValueKey(t.videoId),
                value: isSelected,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedIds.add(t.videoId);
                  } else {
                    _selectedIds.remove(t.videoId);
                  }
                }),
                activeColor: appAccent,
                checkColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: spacingMd, vertical: spacingXs),
                secondary: _thumb(ctx, t.thumbnail),
                title: Text(t.title,
                  style: TextStyle(color: ctx.appTextPrimColor, fontSize: 13),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(t.channel,
                  style: TextStyle(color: ctx.appTextSecColor, fontSize: 11)),
              );
            },
          ),
        ),
        // Botón confirmar
        Padding(
          padding: const EdgeInsets.all(spacingMd),
          child: Row(
            children: [
              // Botón volver
              OutlinedButton(
                onPressed: _reset,
                child: Text('common.back'.tr()),
              ),
              const SizedBox(width: spacingMd),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.playlist_add_rounded, size: 18),
                  label: Text('youtube.add_n_songs'.plural(_selectedCount)),
                  onPressed: _selectedCount == 0 ? null : _importSelected,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Paso 4: Importando ────────────────────────────────────────────────────

  Widget _buildImporting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: appAccent),
          const SizedBox(height: spacingMd),
          Text('youtube.adding_n'.tr(namedArgs: {'n': '$_selectedCount'}),
            style: TextStyle(color: context.appTextSecColor, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Paso 5: Hecho ─────────────────────────────────────────────────────────

  Widget _buildDone() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: appAccentGlow,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.check_rounded, color: appAccent, size: 32),
          ),
          const SizedBox(height: spacingMd),
          Text(
            'youtube.n_added_to_queue'.plural(_selectedCount),
            style: TextStyle(
              color: context.appTextPrimColor, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: spacingLg),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }
}

// ── Helpers compartidos ────────────────────────────────────────────────────────

enum _PlaylistFlowState { idle, loading, preview, importing, done }

Widget _buildHandle(BuildContext context) => Container(
  margin: const EdgeInsets.only(top: 12, bottom: 8),
  width: 40, height: 4,
  decoration: BoxDecoration(
    color: context.appDividerColor,
    borderRadius: BorderRadius.circular(2),
  ),
);

Widget _buildHeader(BuildContext context, String title, IconData icon) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
  child: Row(
    children: [
      Icon(icon, color: appAccent, size: 20),
      const SizedBox(width: spacingSm),
      Text(title,
        style: TextStyle(
          color: context.appTextPrimColor, fontSize: 17, fontWeight: FontWeight.w600)),
      const Spacer(),
      Builder(builder: (ctx) => IconButton(
        icon: Icon(Icons.close_rounded, color: ctx.appTextSecColor, size: 20),
        onPressed: () => Navigator.pop(ctx),
      )),
    ],
  ),
);

Widget _buildEmptyHint(BuildContext context, String text) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.music_note_outlined,
        color: context.appTextSecColor.withValues(alpha: 0.3), size: 48),
      const SizedBox(height: spacingMd),
      Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.appTextSecColor, fontSize: 14)),
    ],
  ),
);

Widget _thumb(BuildContext context, String url) => ClipRRect(
  borderRadius: BorderRadius.circular(radiusSm),
  child: url.isNotEmpty
    ? AppImage(url: url, width: 80, height: 48,
        errorBuilder: (c) => _thumbFallback(c))
    : _thumbFallback(context),
);

Widget _thumbFallback(BuildContext context) => Container(
  width: 80, height: 48,
  color: context.appSurfaceAltColor,
  child: Icon(Icons.music_note, color: context.appTextSecColor),
);
