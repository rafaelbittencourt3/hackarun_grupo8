import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Verdadeiro quando o visitante pediu ao sistema para reduzir animações.
bool reduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Marca do app: uma rosa dos ventos com a ponta norte em destaque.
class CompassMark extends StatelessWidget {
  const CompassMark({
    super.key,
    this.size = 24,
    required this.color,
    required this.accent,
  });

  final double size;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _CompassMarkPainter(color: color, accent: accent),
      ),
    );
  }
}

class _CompassMarkPainter extends CustomPainter {
  const _CompassMarkPainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius * 0.92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.07
        ..color = color,
    );

    Path point(double angle, double length, double width) {
      final tip = center + Offset(math.sin(angle), -math.cos(angle)) * length;
      final left = center + Offset(math.sin(angle - math.pi / 2), -math.cos(angle - math.pi / 2)) * width;
      final right = center + Offset(math.sin(angle + math.pi / 2), -math.cos(angle + math.pi / 2)) * width;

      return Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
    }

    final fill = Paint()..color = color;
    for (final angle in [math.pi / 2, math.pi, 3 * math.pi / 2]) {
      canvas.drawPath(point(angle, radius * 0.58, radius * 0.17), fill);
    }
    canvas.drawPath(point(0, radius * 0.7, radius * 0.19), Paint()..color = accent);
    canvas.drawCircle(center, radius * 0.1, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_CompassMarkPainter old) => old.color != color || old.accent != accent;
}

/// Mostrador da bússola: anel com marcações a cada 15 graus e os pontos
/// cardeais. Gira junto com o celular para o N apontar sempre para o norte.
class CompassDial extends StatelessWidget {
  const CompassDial({
    super.key,
    required this.size,
    required this.ringColor,
    required this.tickColor,
    required this.labelColor,
    required this.northColor,
  });

  final double size;
  final Color ringColor;
  final Color tickColor;
  final Color labelColor;
  final Color northColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CompassDialPainter(
        ringColor: ringColor,
        tickColor: tickColor,
        labelColor: labelColor,
        northColor: northColor,
      ),
    );
  }
}

class _CompassDialPainter extends CustomPainter {
  const _CompassDialPainter({
    required this.ringColor,
    required this.tickColor,
    required this.labelColor,
    required this.northColor,
  });

  final Color ringColor;
  final Color tickColor;
  final Color labelColor;
  final Color northColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, Paint()..color = ringColor);

    for (var degrees = 0; degrees < 360; degrees += 15) {
      final major = degrees % 90 == 0;
      final angle = degrees * math.pi / 180;
      final direction = Offset(math.sin(angle), -math.cos(angle));

      canvas.drawLine(
        center + direction * radius * (major ? 0.84 : 0.9),
        center + direction * radius * 0.96,
        Paint()
          ..strokeWidth = major ? 3 : 1.5
          ..strokeCap = StrokeCap.round
          ..color = degrees == 0 ? northColor : tickColor,
      );
    }

    const labels = {'N': 0.0, 'L': 90.0, 'S': 180.0, 'O': 270.0};
    labels.forEach((label, degrees) {
      final angle = degrees * math.pi / 180;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: label == 'N' ? northColor : labelColor,
            fontSize: radius * 0.14,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final position = center + Offset(math.sin(angle), -math.cos(angle)) * radius * 0.7;

      painter.paint(canvas, position - Offset(painter.width / 2, painter.height / 2));
    });
  }

  @override
  bool shouldRepaint(_CompassDialPainter old) =>
      old.ringColor != ringColor || old.tickColor != tickColor || old.labelColor != labelColor;
}

/// Faz o conteúdo surgir deslizando de baixo, uma única vez.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      return child;
    }

    final total = const Duration(milliseconds: 380) + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, (1 - value) * 14), child: child),
      ),
    );
  }
}

/// Três pontos pulando, mostrados enquanto o guia prepara a resposta.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, required this.color});

  final Color color;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Transform.translate(
                  offset: Offset(
                    0,
                    -5 * math.max(0, math.sin((_controller.value - index * 0.16) * 2 * math.pi)),
                  ),
                  child: CircleAvatar(radius: 4, backgroundColor: widget.color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Anéis que se expandem três vezes ao redor do conteúdo, para marcar a
/// chegada. A animação termina sozinha.
class ArrivalPulse extends StatefulWidget {
  const ArrivalPulse({super.key, required this.color, required this.size, required this.child});

  final Color color;
  final double size;
  final Widget child;

  @override
  State<ArrivalPulse> createState() => _ArrivalPulseState();
}

class _ArrivalPulseState extends State<ArrivalPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (!reduceMotion(context)) {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final cycle = (_controller.value * 3) % 1;
          final running = _controller.isAnimating;

          return Stack(
            alignment: Alignment.center,
            children: [
              if (running)
                Container(
                  width: widget.size * (0.6 + 0.4 * cycle),
                  height: widget.size * (0.6 + 0.4 * cycle),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withOpacity(0.7 * (1 - cycle)),
                      width: 6,
                    ),
                  ),
                ),
              Container(
                width: widget.size * 0.62,
                height: widget.size * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color, width: 5),
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Chuva de confete que cai uma vez, usada na conclusão do roteiro.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.colors});

  final List<Color> colors;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  late final List<_Piece> _pieces = _buildPieces();
  bool _started = false;

  List<_Piece> _buildPieces() {
    final random = math.Random(8);

    return List.generate(70, (index) {
      return _Piece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.35,
        speed: 0.7 + random.nextDouble() * 0.6,
        sway: (random.nextDouble() - 0.5) * 0.18,
        spin: random.nextDouble() * 6,
        size: 6 + random.nextDouble() * 7,
        color: widget.colors[index % widget.colors.length],
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (!reduceMotion(context)) {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(pieces: _pieces, progress: _controller.value),
          ),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.sway,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x;
  final double delay;
  final double speed;
  final double sway;
  final double spin;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.pieces, required this.progress});

  final List<_Piece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) {
      return;
    }

    for (final piece in pieces) {
      final t = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (t <= 0) {
        continue;
      }

      final position = Offset(
        (piece.x + piece.sway * math.sin(t * 6)) * size.width,
        -20 + t * piece.speed * (size.height + 40),
      );

      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(piece.spin * t * 4)
        ..drawRect(
          Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 0.55),
          Paint()..color = piece.color.withOpacity(1 - t * t),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
