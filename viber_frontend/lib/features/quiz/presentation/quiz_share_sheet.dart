import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';

import '../domain/quiz_models.dart';
import 'widgets/quiz_share_card.dart';

/// Abre una hoja con la tarjeta de resultado y la comparte como imagen.
/// La tarjeta se muestra en pantalla (así carga la portada de red) y luego se
/// captura desde el [RepaintBoundary] a PNG para la hoja de compartir nativa.
Future<void> showQuizShareSheet(BuildContext context, QuizGameState state) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appSurfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
    ),
    builder: (_) => _QuizShareSheet(state: state),
  );
}

class _QuizShareSheet extends StatefulWidget {
  final QuizGameState state;
  const _QuizShareSheet({required this.state});

  @override
  State<_QuizShareSheet> createState() => _QuizShareSheetState();
}

class _QuizShareSheetState extends State<_QuizShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();

      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'viber_quiz.png')],
        text: '${'quiz.share_prompt'.tr()}\n$quizShareUrl',
      );
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'quiz.share_error'.tr(), error: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // Respaldo spoiler-free (texto) — útil en navegadores de escritorio donde
  // compartir imágenes no está soportado. Igual que el "share" de Wordle.
  void _copyText() {
    final state = widget.state;
    final mode = 'quiz.${state.mode.name}_title'.tr();

    final grid = StringBuffer();
    for (final g in state.guesses) {
      grid.write(g.skipped
          ? '⬛'
          : g.correct
              ? '🟩'
              : '🟥');
    }
    final score = state.solved
        ? (state.maxAttempts != null
            ? '${state.attemptsUsed}/${state.maxAttempts}'
            : '${state.attemptsUsed}')
        : '✗';
    final header = (state.practice || state.date == null)
        ? 'Viber Quiz · $mode'
        : 'Viber Quiz · $mode · ${state.date}';

    Clipboard.setData(ClipboardData(
      text: '$header\n$grid  $score\n\n'
          '${'quiz.share_prompt'.tr()}\n$quizShareUrl',
    ));
    AppSnackBar.show(context, 'quiz.share_copied'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardWidth = screenW < 392 ? screenW - 2 * spacingLg : 360.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            spacingLg, spacingMd, spacingLg, spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: spacingLg),
              decoration: BoxDecoration(
                color: context.appDividerColor,
                borderRadius: BorderRadius.circular(radiusFull),
              ),
            ),

            // Previsualización capturable
            RepaintBoundary(
              key: _cardKey,
              child: QuizShareCard(state: widget.state, width: cardWidth),
            ),

            const SizedBox(height: spacingLg),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _sharing ? null : _shareImage,
                icon: _sharing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.share_rounded, size: 18),
                label: Text('quiz.share_button'.tr()),
              ),
            ),
            const SizedBox(height: spacingXs),
            TextButton.icon(
              onPressed: _sharing ? null : _copyText,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text('quiz.share_copy_text'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
