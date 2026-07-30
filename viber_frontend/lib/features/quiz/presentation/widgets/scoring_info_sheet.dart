import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';

/// Hoja explicativa de cómo funciona la puntuación del quiz. Se abre desde el
/// botón de info de la pantalla de clasificación. Texto "un poco" — lo justo
/// para que se entienda sin abrumar. Los números casan con las constantes del
/// backend (200 / 30 / 50, +20, racha +5 hasta +50).
class ScoringInfoSheet extends StatelessWidget {
  const ScoringInfoSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const ScoringInfoSheet(),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusXl)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              spacingLg, spacingSm, spacingLg, spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Asa de arrastre
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: spacingMd),
                  decoration: BoxDecoration(
                    color: context.appDividerColor,
                    borderRadius: BorderRadius.circular(radiusFull),
                  ),
                ),
              ),

              // Título
              Row(
                children: [
                  Icon(Icons.stars_rounded,
                      color: context.appAccentColor, size: 22),
                  const SizedBox(width: spacingSm),
                  Expanded(
                    child: Text(
                      'quiz.score_title'.tr(),
                      style: TextStyle(
                        color: context.appTextPrimColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: spacingXs),
              Text(
                'quiz.score_intro'.tr(),
                style: TextStyle(
                    color: context.appTextSecColor, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: spacingLg),

              // Reglas
              _Rule(
                icon: Icons.bolt_rounded,
                iconColor: context.appAccentColor,
                title: 'quiz.score_solve_title'.tr(),
                desc: 'quiz.score_solve_desc'.tr(),
              ),
              _Rule(
                icon: Icons.add_circle_outline_rounded,
                iconColor: context.appAccentColor,
                title: 'quiz.score_participation_title'.tr(),
                desc: 'quiz.score_participation_desc'.tr(),
              ),
              _Rule(
                icon: Icons.local_fire_department_rounded,
                iconColor: appEnergy,
                title: 'quiz.score_streak_title'.tr(),
                desc: 'quiz.score_streak_desc'.tr(),
              ),
              _Rule(
                icon: Icons.emoji_events_rounded,
                iconColor: context.appAccentColor,
                title: 'quiz.score_scope_title'.tr(),
                desc: 'quiz.score_scope_desc'.tr(),
              ),

              const SizedBox(height: spacingSm),

              // Ejemplo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(spacingMd),
                decoration: BoxDecoration(
                  color: context.appAccentDimColor,
                  borderRadius: BorderRadius.circular(radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 18, color: context.appAccentColor),
                    const SizedBox(width: spacingSm),
                    Expanded(
                      child: Text(
                        'quiz.score_example'.tr(),
                        style: TextStyle(
                          color: context.appTextPrimColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: spacingSm),
              Text(
                'quiz.score_tie'.tr(),
                style: TextStyle(
                    color: context.appTextDimColor, fontSize: 11.5, height: 1.3),
              ),

              const SizedBox(height: spacingMd),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('quiz.score_got_it'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una regla: icono + título + descripción corta.
class _Rule extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String desc;

  const _Rule({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.appCard2Color,
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.appTextPrimColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: context.appTextSecColor,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
