import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_image.dart';

import '../../domain/quiz_models.dart';
import '../../infrastructure/quiz_service.dart';

/// Buscador de intentos: autocompleta contra el pool del quiz (nunca contra
/// YouTube). Con debounce de 300 ms y excluyendo canciones ya probadas.
class SongAutocompleteField extends StatefulWidget {
  final QuizMode mode;
  final bool enabled;
  final Set<int> excludedIds;
  final void Function(QuizPoolSong song) onSelected;

  /// false en el modo portada: ver las carátulas en miniatura permitiría
  /// compararlas visualmente con la portada pixelada.
  final bool showCovers;

  const SongAutocompleteField({
    super.key,
    required this.mode,
    required this.enabled,
    required this.onSelected,
    this.excludedIds = const {},
    this.showCovers = true,
  });

  @override
  State<SongAutocompleteField> createState() => _SongAutocompleteFieldState();
}

class _SongAutocompleteFieldState extends State<SongAutocompleteField> {
  final _service = QuizService();
  final _controller = TextEditingController();

  Timer? _debounce;
  List<QuizPoolSong> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final results = await _service.searchSongs(query, widget.mode);
      if (!mounted) return;
      setState(() => _results =
          results.where((s) => !widget.excludedIds.contains(s.id)).toList());
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(QuizPoolSong song) {
    _controller.clear();
    setState(() => _results = []);
    widget.onSelected(song);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'quiz.search_hint'.tr(),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: spacingXs),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: context.appCardColor,
              borderRadius: BorderRadius.circular(radiusMd),
              border: Border.all(color: context.appDividerColor),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: spacingXs),
              itemCount: _results.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: context.appDividerColor),
              itemBuilder: (_, i) {
                final song = _results[i];
                return ListTile(
                  dense: true,
                  leading: _Cover(
                      url: widget.showCovers ? song.coverUrl : null),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appTextPrimColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    song.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.appTextSecColor, fontSize: 12),
                  ),
                  onTap: () => _select(song),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  final String? url;
  const _Cover({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radiusSm),
      child: SizedBox(
        width: 36,
        height: 36,
        child: url != null
            ? AppImage(
                url: url!,
                fit: BoxFit.cover,
                errorBuilder: (c) => _fallback(c),
              )
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) => Container(
        color: context.appCard2Color,
        child: Icon(Icons.music_note_rounded,
            size: 18, color: context.appTextDimColor),
      );
}
