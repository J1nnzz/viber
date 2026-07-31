import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:viber/core/constants/api_constants.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_image.dart';

/// Sección del panel de administración para el pool de canciones del quiz.
///
/// Flujo: importar una playlist pública de YouTube (el backend matchea cada
/// vídeo contra Deezer), revisar las que queden incompletas, corregirlas a
/// mano o re-matchear, y activar/desactivar canciones del pool.
class QuizPoolPage extends StatefulWidget {
  final Future<String> Function() getAuthHeader;
  const QuizPoolPage({super.key, required this.getAuthHeader});

  @override
  State<QuizPoolPage> createState() => _QuizPoolPageState();
}

enum _Filter { all, incomplete, noPreview, noLyrics, noEmojis }

class _QuizPoolPageState extends State<QuizPoolPage> {
  List<dynamic> _songs = [];
  bool _loading = true;
  bool _importing = false;
  bool _fetchingLyrics = false;
  bool _suggestingEmojis = false;
  _Filter _filter = _Filter.all;

  final _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers() async => {
        'Content-Type': 'application/json',
        'Authorization': await widget.getAuthHeader(),
      };

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/admin/quiz/songs'),
        headers: await _headers(),
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _songs = jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || _importing) return;

    setState(() => _importing = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/quiz/import-playlist'),
        headers: await _headers(),
        body: jsonEncode({'url': url, 'max': 50}),
      );
      if (!mounted) return;

      if (res.statusCode == 200) {
        final summary = jsonDecode(res.body);
        _urlCtrl.clear();
        _snack(
          'admin.import_summary'.tr(namedArgs: {
            'matched': '${summary['matched']}',
            'unmatched': '${summary['unmatched']}',
            'skipped': '${summary['skipped']}',
          }),
        );
        _load();
      } else {
        _snack(jsonDecode(res.body)['error'] ?? 'errors.import_failed'.tr(),
            error: true);
      }
    } catch (e) {
      if (mounted) _snack('errors.import_failed_detail'.tr(namedArgs: {'error': '$e'}), error: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _update(dynamic id, Map<String, dynamic> changes) async {
    final res = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/admin/quiz/songs/$id'),
      headers: await _headers(),
      body: jsonEncode(changes),
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      _load();
    } else {
      _snack(jsonDecode(res.body)['error'] ?? 'errors.save_failed'.tr(), error: true);
    }
  }

  /// Busca en lrclib las letras de las canciones que aún no tienen
  /// (necesarias para el modo letra del quiz).
  Future<void> _fetchLyrics() async {
    if (_fetchingLyrics) return;
    setState(() => _fetchingLyrics = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/quiz/fetch-lyrics'),
        headers: await _headers(),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final summary = jsonDecode(res.body);
        final remaining = (summary['remaining'] as num?)?.toInt() ?? 0;
        _snack(
          'admin.lyrics_summary'.tr(namedArgs: {
            'found': '${summary['found']}',
            'checked': '${summary['checked']}',
          }) +
              (remaining > 0
                  ? 'admin.more_remaining'.tr(namedArgs: {'n': '$remaining'})
                  : ''),
        );
        _load();
      } else {
        _snack(jsonDecode(res.body)['error'] ?? 'Error buscando letras',
            error: true);
      }
    } catch (e) {
      if (mounted) _snack('Error buscando letras: $e', error: true);
    } finally {
      if (mounted) setState(() => _fetchingLyrics = false);
    }
  }

  /// Genera con Claude los emojis de las canciones que aún no tienen.
  /// Procesa un lote por pulsación; si quedan más, vuelve a pulsar.
  Future<void> _suggestEmojis() async {
    if (_suggestingEmojis) return;
    setState(() => _suggestingEmojis = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/quiz/suggest-emojis'),
        headers: await _headers(),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final summary = jsonDecode(utf8.decode(res.bodyBytes));
        final remaining = summary['remaining'] ?? 0;
        _snack(
          'admin.emojis_summary'.tr(namedArgs: {
            'found': '${summary['found']}',
            'checked': '${summary['checked']}',
          }) +
              (remaining > 0
                  ? 'admin.more_remaining'.tr(namedArgs: {'n': '$remaining'})
                  : ''),
        );
        _load();
      } else {
        _snack(jsonDecode(res.body)['error'] ?? 'Error generando emojis',
            error: true);
      }
    } catch (e) {
      if (mounted) _snack('Error generando emojis: $e', error: true);
    } finally {
      if (mounted) setState(() => _suggestingEmojis = false);
    }
  }

  Future<void> _rematch(dynamic id) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/admin/quiz/songs/$id/rematch'),
      headers: await _headers(),
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      _snack('admin.song_rematched'.tr());
      _load();
    } else {
      _snack(jsonDecode(res.body)['error'] ?? 'admin.no_deezer_results'.tr(),
          error: true);
    }
  }

  Future<void> _delete(dynamic song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.delete_song'.tr()),
        content: Text('admin.delete_song_confirm'.tr(namedArgs: {'title': '${song['title']}'})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('common.delete'.tr())),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/admin/quiz/songs/${song['id']}'),
      headers: await _headers(),
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      _load();
    } else {
      _snack(jsonDecode(res.body)['error'] ?? 'errors.delete_failed'.tr(),
          error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: error ? appError : null,
      behavior: SnackBarBehavior.floating,
      width: 400,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
    ));
  }

  // ── Helpers de estado de canción ───────────────────────────────────────────

  bool _isIncomplete(dynamic s) =>
      s['releaseYear'] == null || s['genre'] == null || s['durationSec'] == null;

  bool _hasNoPreview(dynamic s) => s['hasPreview'] != true;

  bool _hasNoLyrics(dynamic s) => s['hasLyrics'] != true;

  bool _hasNoEmojis(dynamic s) =>
      s['emojis'] == null || (s['emojis'] as String).trim().isEmpty;

  List<dynamic> get _visibleSongs => switch (_filter) {
        _Filter.all => _songs,
        _Filter.incomplete => _songs.where(_isIncomplete).toList(),
        _Filter.noPreview => _songs.where(_hasNoPreview).toList(),
        _Filter.noLyrics => _songs.where(_hasNoLyrics).toList(),
        _Filter.noEmojis => _songs.where(_hasNoEmojis).toList(),
      };

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Import ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      enabled: !_importing,
                      decoration: InputDecoration(
                        hintText:
                            'admin.playlist_url'.tr(),
                        prefixIcon: Icon(Icons.playlist_add_rounded),
                      ),
                      onSubmitted: (_) => _import(),
                    ),
                  ),
                  const SizedBox(width: spacingSm),
                  ElevatedButton.icon(
                    onPressed: _importing ? null : _import,
                    icon: _importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(_importing ? 'Importando…' : 'Importar'),
                  ),
                  const SizedBox(width: spacingSm),
                  OutlinedButton.icon(
                    onPressed: _fetchingLyrics ? null : _fetchLyrics,
                    icon: _fetchingLyrics
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lyrics_outlined, size: 18),
                    label: Text(
                        _fetchingLyrics ? 'Buscando…' : 'Buscar letras'),
                  ),
                  const SizedBox(width: spacingSm),
                  OutlinedButton.icon(
                    onPressed: _suggestingEmojis ? null : _suggestEmojis,
                    icon: _suggestingEmojis
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined, size: 18),
                    label: Text(
                        _suggestingEmojis ? 'Generando…' : 'Emojis (IA)'),
                  ),
                ],
              ),
              if (_importing)
                Padding(
                  padding: const EdgeInsets.only(top: spacingSm),
                  child: Text(
                    'admin.matching_deezer'.tr(),
                    style: TextStyle(
                        color: context.appTextSecColor, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),

        // ── Filtros ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: spacingMd),
          child: Wrap(
            spacing: spacingSm,
            children: [
              _filterChip('Todas (${_songs.length})', _Filter.all),
              _filterChip(
                  'Incompletas (${_songs.where(_isIncomplete).length})',
                  _Filter.incomplete),
              _filterChip(
                  'admin.filter_no_preview'.tr(namedArgs: {'n': '${_songs.where(_hasNoPreview).length}'}),
                  _Filter.noPreview),
              _filterChip(
                  'admin.filter_no_lyrics'.tr(namedArgs: {'n': '${_songs.where(_hasNoLyrics).length}'}),
                  _Filter.noLyrics),
              _filterChip(
                  'admin.filter_no_emojis'.tr(namedArgs: {'n': '${_songs.where(_hasNoEmojis).length}'}),
                  _Filter.noEmojis),
            ],
          ),
        ),
        const SizedBox(height: spacingSm),

        // ── Lista ──────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _visibleSongs.isEmpty
                  ? Center(
                      child: Text(
                        _songs.isEmpty
                            ? 'admin.pool_empty'.tr()
                            : 'admin.no_songs_filter'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.appTextSecColor),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(spacingMd),
                      itemCount: _visibleSongs.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: spacingXs),
                      itemBuilder: (_, i) => _songTile(_visibleSongs[i]),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, _Filter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _songTile(dynamic s) {
    final incomplete = _isIncomplete(s);
    final inactive = s['active'] == false;

    final details = <String>[
      if (s['releaseYear'] != null) '${s['releaseYear']}',
      if (s['genre'] != null) s['genre'],
      if (s['durationSec'] != null) _fmtDuration(s['durationSec']),
      'letra ${_hasNoLyrics(s) ? '—' : '✓'}',
      'emojis ${_hasNoEmojis(s) ? '—' : (s['emojis'] as String).trim()}',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: context.appDividerColor),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(radiusSm),
          child: SizedBox(
            width: 40,
            height: 40,
            child: s['coverUrl'] != null
                ? AppImage(
                    url: s['coverUrl'],
                    fit: BoxFit.cover,
                    errorBuilder: (c) => Container(
                      color: c.appCard2Color,
                      child: const Icon(Icons.music_note_rounded, size: 18),
                    ),
                  )
                : Container(
                    color: context.appCard2Color,
                    child: const Icon(Icons.music_note_rounded, size: 18),
                  ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                '${s['title']} — ${s['artistName'] ?? '?'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: inactive
                      ? context.appTextDimColor
                      : context.appTextPrimColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: inactive ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (incomplete) _badge('Incompleta', appError),
            if (_hasNoPreview(s)) _badge('admin.no_preview'.tr(), quizWarn),
            if (inactive) _badge('Inactiva', appTextDim),
          ],
        ),
        subtitle: Text(
          details.isEmpty ? 'admin.no_metadata'.tr() : details,
          style: TextStyle(color: context.appTextSecColor, fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => switch (action) {
            'edit' => _showEditDialog(s),
            'rematch' => _rematch(s['id']),
            'toggle' => _update(s['id'], {'active': inactive}),
            'delete' => _delete(s),
            _ => null,
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text('common.edit'.tr())),
            PopupMenuItem(
                value: 'rematch', child: Text('admin.rematch_deezer'.tr())),
            PopupMenuItem(
                value: 'toggle',
                child: Text(inactive ? 'Activar' : 'Desactivar')),
            PopupMenuItem(value: 'delete', child: Text('common.delete'.tr())),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radiusFull),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  static String _fmtDuration(dynamic seconds) {
    final total = seconds is num ? seconds.toInt() : 0;
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  // ── Diálogo de edición ─────────────────────────────────────────────────────

  Future<void> _showEditDialog(dynamic s) async {
    final titleCtrl = TextEditingController(text: s['title'] ?? '');
    final artistCtrl = TextEditingController(text: s['artistName'] ?? '');
    final yearCtrl =
        TextEditingController(text: s['releaseYear']?.toString() ?? '');
    final genreCtrl = TextEditingController(text: s['genre'] ?? '');
    final durationCtrl =
        TextEditingController(text: s['durationSec']?.toString() ?? '');
    final emojisCtrl = TextEditingController(text: s['emojis'] ?? '');
    final lyricsCtrl = TextEditingController(text: s['lyrics'] ?? '');
    bool explicit = s['explicit'] == true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('admin.edit_song'.tr()),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(labelText: 'admin.song_title'.tr()),
                  ),
                  const SizedBox(height: spacingSm),
                  TextField(
                    controller: artistCtrl,
                    decoration: InputDecoration(labelText: 'admin.song_artist'.tr()),
                  ),
                  const SizedBox(height: spacingSm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: yearCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              InputDecoration(labelText: 'admin.song_year'.tr()),
                        ),
                      ),
                      const SizedBox(width: spacingSm),
                      Expanded(
                        child: TextField(
                          controller: durationCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: 'admin.song_duration'.tr()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: spacingSm),
                  TextField(
                    controller: genreCtrl,
                    decoration: InputDecoration(
                        labelText: 'admin.song_genre'.tr()),
                  ),
                  const SizedBox(height: spacingSm),
                  TextField(
                    controller: emojisCtrl,
                    decoration: InputDecoration(
                      labelText: 'admin.song_emojis'.tr(),
                      hintText: 'admin.song_emojis_hint'.tr(),
                    ),
                  ),
                  const SizedBox(height: spacingSm),
                  TextField(
                    controller: lyricsCtrl,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'admin.song_lyrics'.tr(),
                      hintText: 'admin.song_lyrics_hint'.tr(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: spacingSm),
                  CheckboxListTile(
                    value: explicit,
                    onChanged: (v) =>
                        setDialogState(() => explicit = v ?? false),
                    title: Text('admin.explicit_lyrics'.tr(),
                        style: TextStyle(fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('common.cancel'.tr())),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('common.save'.tr())),
          ],
        ),
      ),
    );

    if (saved == true) {
      await _update(s['id'], {
        'title': titleCtrl.text.trim(),
        'artistName': artistCtrl.text.trim(),
        'releaseYear': int.tryParse(yearCtrl.text.trim()),
        'genre': genreCtrl.text.trim().isEmpty ? null : genreCtrl.text.trim(),
        'durationSec': int.tryParse(durationCtrl.text.trim()),
        'explicit': explicit,
        'emojis':
            emojisCtrl.text.trim().isEmpty ? null : emojisCtrl.text.trim(),
        'lyrics':
            lyricsCtrl.text.trim().isEmpty ? null : lyricsCtrl.text.trim(),
      });
    }

    titleCtrl.dispose();
    artistCtrl.dispose();
    yearCtrl.dispose();
    genreCtrl.dispose();
    durationCtrl.dispose();
    emojisCtrl.dispose();
    lyricsCtrl.dispose();
  }
}

/// Ámbar para avisos del pool (sin token semántico propio en AppTheme).
const Color quizWarn = Color(0xFFE5A53A);
