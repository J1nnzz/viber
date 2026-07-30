import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
// VIBER — Motion toolkit
// ══════════════════════════════════════════════════════════════════════════════
// Primitivas de animación reutilizables, en la misma línea que los widgets del
// design-system (AppPrimaryButton, AppCard…). El objetivo es transmitir la
// identidad de Viber: música compartida, EN DIRECTO y en tiempo real.
//
// Todas respetan `MediaQuery.disableAnimations` (accesibilidad / "reducir
// movimiento" del sistema): cuando está activo, las animaciones en bucle se
// detienen y se muestra un estado estático equivalente.
//
//   LiveDot        → punto "en directo" que late con un anillo de radar
//   EqualizerBars  → barras de ecualizador que bailan con la música
//   PressableScale → feedback táctil: el hijo se hunde al pulsar
//   AppEntrance    → entrada escalonada (fade + desplazamiento) para listas
//   ShimmerBox     → placeholder con brillo en movimiento para estados de carga
// ══════════════════════════════════════════════════════════════════════════════

/// Punto "en directo" que late con un anillo de radar expandiéndose.
///
/// Reemplaza los círculos estáticos de `appEnergy` que marcaban actividad
/// (oyentes en sala, conexión del mini-player…). El latido comunica que la
/// sala está VIVA sin ocupar más espacio.
class LiveDot extends StatefulWidget {
  /// Color del punto y del anillo. Por defecto el coral "energía" de marca.
  final Color color;

  /// Diámetro del punto sólido central.
  final double size;

  /// Si es false se pinta un punto estático (sin latido) — útil para estados
  /// "sin oyentes" donde queremos el punto pero no el movimiento.
  final bool active;

  const LiveDot({
    super.key,
    this.color = appEnergy,
    this.size = 7,
    this.active = true,
  });

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(LiveDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );

    if (!widget.active || reduceMotion) return dot;

    // El anillo puede crecer hasta 2.6× el punto: reservamos ese espacio para
    // que el latido no desplace el layout de alrededor.
    final box = widget.size * 2.6;
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final t = _c.value; // 0 → 1
            return Stack(
              alignment: Alignment.center,
              children: [
                // Anillo de radar: crece y se desvanece.
                Opacity(
                  opacity: (1 - t) * 0.55,
                  child: Container(
                    width: widget.size * (1 + t * 1.6),
                    height: widget.size * (1 + t * 1.6),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.40),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: dot,
        ),
      ),
    );
  }
}

/// Barras de ecualizador que bailan: la firma visual de una app de música.
///
/// Cuando [playing] es true las barras oscilan con alturas desfasadas; cuando
/// es false se asientan en una línea baja estática. Una sola animación mueve
/// todas las barras (barato), con una onda seno por barra.
class EqualizerBars extends StatefulWidget {
  final bool playing;
  final Color color;
  final int barCount;
  final double height;
  final double barWidth;
  final double spacing;

  const EqualizerBars({
    super.key,
    this.playing = true,
    this.color = appEnergy,
    this.barCount = 4,
    this.height = 12,
    this.barWidth = 2.5,
    this.spacing = 2.5,
  });

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Frecuencia/fase por barra para que no se muevan al unísono.
  late final List<double> _phase = List.generate(
    widget.barCount,
    (i) => i * 0.7,
  );
  late final List<double> _freq = List.generate(
    widget.barCount,
    (i) => 1.0 + (i % 3) * 0.45,
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(EqualizerBars old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animate = widget.playing && !reduceMotion;

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (i) {
              double frac;
              if (animate) {
                final s = math.sin(
                  (_c.value * 2 * math.pi * _freq[i]) + _phase[i],
                );
                frac = 0.30 + (s + 1) / 2 * 0.70; // 0.30 → 1.0
              } else {
                frac = 0.30; // asentado: línea baja
              }
              return Padding(
                padding: EdgeInsets.only(
                    right: i == widget.barCount - 1 ? 0 : widget.spacing),
                child: Container(
                  width: widget.barWidth,
                  height: widget.height * frac,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(widget.barWidth),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// Envuelve a un hijo y lo "hunde" ligeramente al pulsar (feedback táctil).
///
/// Pensado para tarjetas y elementos grandes donde el ripple de Material no
/// basta para que la pulsación se sienta física. No interfiere con scroll.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Entrada escalonada: el hijo aparece con fade + un pequeño desplazamiento
/// vertical. Aplicar a los elementos de una lista con [delay] creciente para
/// un efecto "cascada" al cargar.
class AppEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Desplazamiento inicial en píxeles (positivo = entra desde abajo).
  final double offsetY;

  const AppEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 14,
  });

  @override
  State<AppEntrance> createState() => _AppEntranceState();
}

class _AppEntranceState extends State<AppEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    final reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduceMotion) {
      _c.value = 1.0;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (_, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offsetY),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Caja con un brillo que recorre la superficie: placeholder de carga
/// (skeleton). Reemplaza el spinner suelto por una silueta del contenido real,
/// reduciendo el salto de layout y la sensación de lentitud.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.appCard2Color;
    final highlight = context.appSurfaceAltColor;
    final radius = widget.borderRadius ?? BorderRadius.circular(radiusMd);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: radius),
      );
    }

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final dx = (_c.value * 2) - 1; // -1 → 1
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(dx - 0.6, 0),
              end: Alignment(dx + 0.6, 0),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

/// Transición de página estilo "fade-through" (Material 3): la pantalla entrante
/// se funde mientras hace un ligero zoom desde 0.96×. Reemplaza a
/// `MaterialPageRoute` para que navegar se sienta cohesionado y no un corte seco.
///
///   Navigator.push(context, fadeThroughRoute(const MiPantalla()));
Route<T> fadeThroughRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) return child;
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

/// Reemplazo directo de [IndexedStack] que hace un "fade-through" (fundido +
/// micro-zoom) al cambiar de índice, en lugar de un corte seco. Igual que
/// IndexedStack, mantiene TODOS los hijos montados, así que el estado de cada
/// pestaña (WebSocket de salas, polling de chat…) se conserva intacto.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 160),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration, value: 1.0);
  late int _index = widget.index;

  @override
  void didUpdateWidget(FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      setState(() => _index = widget.index);
      return;
    }
    // Funde la pestaña saliente, intercambia el índice y funde la entrante.
    _c.reverse().then((_) {
      if (!mounted) return;
      setState(() => _index = widget.index);
      _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: ScaleTransition(
        scale: Tween(begin: 0.985, end: 1.0).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeOut),
        ),
        child: IndexedStack(index: _index, children: widget.children),
      ),
    );
  }
}

/// Tipo de reacción one-shot para un elemento que acaba de aparecer.
enum FeedbackKind {
  /// Entrada neutra: fundido + leve desplazamiento vertical.
  entrance,

  /// Acierto: "pop" con un pequeño rebote de escala.
  success,

  /// Fallo: sacudida horizontal amortiguada.
  error,
}

/// Reproduce UNA animación al montarse, según [kind]. Pensado para las filas de
/// intento del quiz: las ya existentes entran neutras y la recién añadida
/// celebra (acierto) o se sacude (fallo). Como es one-shot en `initState`,
/// combínalo con una `Key` estable por elemento para que solo el nuevo reaccione.
class FeedbackEntrance extends StatefulWidget {
  final Widget child;
  final FeedbackKind kind;

  const FeedbackEntrance({
    super.key,
    required this.child,
    this.kind = FeedbackKind.entrance,
  });

  @override
  State<FeedbackEntrance> createState() => _FeedbackEntranceState();
}

class _FeedbackEntranceState extends State<FeedbackEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final dur = switch (widget.kind) {
      FeedbackKind.error => const Duration(milliseconds: 460),
      FeedbackKind.success => const Duration(milliseconds: 520),
      FeedbackKind.entrance => const Duration(milliseconds: 380),
    };
    _c = AnimationController(vsync: this, duration: dur);
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduceMotion) {
      _c.value = 1.0;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        switch (widget.kind) {
          case FeedbackKind.error:
            // Sacudida amortiguada: oscila y se va calmando hacia 0.
            final dx = math.sin(v * math.pi * 5) * 9 * (1 - v);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          case FeedbackKind.success:
            final scale =
                Tween(begin: 0.8, end: 1.0).transform(Curves.easeOutBack.transform(v));
            return Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            );
          case FeedbackKind.entrance:
            final t = Curves.easeOutCubic.transform(v);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                  offset: Offset(0, (1 - t) * 10), child: child),
            );
        }
      },
      child: widget.child,
    );
  }
}
