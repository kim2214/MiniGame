import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../runner_game.dart';

abstract class _ParallaxLayer extends PositionComponent
    with HasGameRef<RunnerGame> {
  _ParallaxLayer({required this.speedMultiplier, required int layerPriority})
      : super(priority: layerPriority);

  final double speedMultiplier;
  double scrollOffset = 0;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = gameRef.size.clone();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.state == GameState.playing) {
      scrollOffset += gameRef.gameSpeed * speedMultiplier * dt;
    }
  }
}

class SkyLayer extends _ParallaxLayer {
  SkyLayer() : super(speedMultiplier: 0, layerPriority: -100);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF5BAEEA), // 짙은 하늘색 (상단)
          Color(0xFFC9E8F2), // 옅은 하늘색 (지평선)
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }
}

class SunLayer extends _ParallaxLayer {
  SunLayer() : super(speedMultiplier: 0, layerPriority: -95);

  static final _glowPaint = Paint()..color = Colors.yellow.withOpacity(0.25);
  static final _midGlowPaint = Paint()..color = Colors.yellow.withOpacity(0.45);
  static final _sunPaint = Paint()..color = const Color(0xFFFFE066);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cx = size.x - 90;
    const cy = 90.0;
    canvas.drawCircle(Offset(cx, cy), 60, _glowPaint);
    canvas.drawCircle(Offset(cx, cy), 45, _midGlowPaint);
    canvas.drawCircle(Offset(cx, cy), 32, _sunPaint);
  }
}

class DistantMountainLayer extends _ParallaxLayer {
  DistantMountainLayer() : super(speedMultiplier: 0.08, layerPriority: -80);

  static const double _patternWidth = 700;
  static const double _baselineFromBottom = 100;
  static final _paint = Paint()..color = const Color(0xFF6E8AA8);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final baseline = size.y - _baselineFromBottom;
    final offset = scrollOffset % _patternWidth;

    for (double xStart = -_patternWidth - offset;
        xStart < size.x + _patternWidth;
        xStart += _patternWidth) {
      final path = Path()
        ..moveTo(xStart, baseline)
        ..lineTo(xStart + 130, baseline - 170)
        ..lineTo(xStart + 230, baseline - 110)
        ..lineTo(xStart + 340, baseline - 200)
        ..lineTo(xStart + 470, baseline - 90)
        ..lineTo(xStart + 580, baseline - 150)
        ..lineTo(xStart + _patternWidth, baseline)
        ..close();
      canvas.drawPath(path, _paint);
    }
  }
}

class _CloudData {
  const _CloudData({required this.x, required this.y, required this.scale});

  final double x;
  final double y;
  final double scale;
}

class CloudLayer extends _ParallaxLayer {
  CloudLayer() : super(speedMultiplier: 0.18, layerPriority: -70);

  static const double _patternWidth = 500;
  static final List<_CloudData> _clouds = _generateClouds();
  static final _paint = Paint()..color = Colors.white.withOpacity(0.9);

  static List<_CloudData> _generateClouds() {
    final rng = Random(42);
    return List.generate(4, (_) {
      return _CloudData(
        x: rng.nextDouble() * _patternWidth,
        y: 40 + rng.nextDouble() * 110,
        scale: 0.7 + rng.nextDouble() * 0.6,
      );
    });
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final offset = scrollOffset % _patternWidth;

    for (double xStart = -_patternWidth - offset;
        xStart < size.x + _patternWidth;
        xStart += _patternWidth) {
      for (final c in _clouds) {
        _drawCloud(canvas, xStart + c.x, c.y, c.scale);
      }
    }
  }

  void _drawCloud(Canvas canvas, double x, double y, double scale) {
    final r = 22.0 * scale;
    canvas.drawCircle(Offset(x, y), r, _paint);
    canvas.drawCircle(Offset(x + r * 0.85, y - r * 0.35), r * 0.85, _paint);
    canvas.drawCircle(Offset(x + r * 1.7, y), r * 0.95, _paint);
    canvas.drawCircle(Offset(x + r * 0.5, y + r * 0.25), r * 0.7, _paint);
    canvas.drawCircle(Offset(x + r * 1.25, y + r * 0.3), r * 0.65, _paint);
  }
}

class HillLayer extends _ParallaxLayer {
  HillLayer() : super(speedMultiplier: 0.35, layerPriority: -60);

  static const double _patternWidth = 480;
  static const double _baselineFromBottom = 100;
  static final _paint = Paint()..color = const Color(0xFF558B2F);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final baseline = size.y - _baselineFromBottom;
    final offset = scrollOffset % _patternWidth;

    for (double xStart = -_patternWidth - offset;
        xStart < size.x + _patternWidth;
        xStart += _patternWidth) {
      final path = Path()
        ..moveTo(xStart, baseline)
        ..quadraticBezierTo(
            xStart + 120, baseline - 100, xStart + 240, baseline)
        ..quadraticBezierTo(
            xStart + 360, baseline - 80, xStart + _patternWidth, baseline)
        ..lineTo(xStart + _patternWidth, baseline + 20)
        ..lineTo(xStart, baseline + 20)
        ..close();
      canvas.drawPath(path, _paint);
    }
  }
}
