import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../runner_game.dart';

class MilestonePopup extends PositionComponent with HasGameRef<RunnerGame> {
  MilestonePopup({required this.scoreValue})
      : super(priority: 95, anchor: Anchor.center);

  final int scoreValue;
  double _lifetime = 0;

  static const double _fadeInEnd = 0.15;
  static const double _settleEnd = 0.30;
  static const double _holdEnd = 0.60;
  static const double _totalDuration = 0.95;

  late final Color _baseColor;
  late final TextStyle _baseStyle;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _baseColor = _colorFor(scoreValue);
    _baseStyle = TextStyle(
      color: _baseColor,
      fontSize: 72,
      fontWeight: FontWeight.bold,
      shadows: const [
        Shadow(color: Colors.black87, offset: Offset(2, 2), blurRadius: 6),
      ],
    );
    // 화면 정중앙보다 살짝 위
    position = gameRef.size / 2 - Vector2(0, 70);
  }

  static Color _colorFor(int score) {
    if (score >= 2000) return const Color(0xFFFF4081); // 핫핑크
    if (score >= 1500) return Colors.redAccent;
    if (score >= 1000) return Colors.orangeAccent;
    return Colors.yellowAccent;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    if (_lifetime >= _totalDuration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final t = _lifetime;
    double opacity;
    double scale;

    if (t < _fadeInEnd) {
      final p = t / _fadeInEnd;
      opacity = p;
      scale = 0.5 + 0.7 * p; // 0.5 -> 1.2 (오버슈트)
    } else if (t < _settleEnd) {
      final p = (t - _fadeInEnd) / (_settleEnd - _fadeInEnd);
      opacity = 1.0;
      scale = 1.2 - 0.2 * p; // 1.2 -> 1.0
    } else if (t < _holdEnd) {
      opacity = 1.0;
      scale = 1.0;
    } else {
      final p = (t - _holdEnd) / (_totalDuration - _holdEnd);
      opacity = (1 - p).clamp(0.0, 1.0);
      scale = 1.0 + 0.15 * p; // 살짝 커지면서 사라짐
    }

    final painter = TextPainter(
      text: TextSpan(
        text: '$scoreValue!',
        style: _baseStyle.copyWith(color: _baseColor.withOpacity(opacity)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.scale(scale, scale);
    painter.paint(
      canvas,
      Offset(-painter.width / 2, -painter.height / 2),
    );
    canvas.restore();
  }
}
