import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../runner_game.dart';

// ─────────────────────────────────────────────────────────────
// Day/Night 사이클 페이즈
// ─────────────────────────────────────────────────────────────

class Phase {
  const Phase({
    required this.topSky,
    required this.bottomSky,
    required this.sunColor,
    required this.sunOpacity,
    required this.moonOpacity,
    required this.starOpacity,
    required this.atmosphereColor,
    required this.atmosphereAlpha,
  });

  final Color topSky;
  final Color bottomSky;
  final Color sunColor;
  final double sunOpacity;
  final double moonOpacity;
  final double starOpacity;
  final Color atmosphereColor;
  final double atmosphereAlpha;

  static Phase lerp(Phase a, Phase b, double t) {
    return Phase(
      topSky: Color.lerp(a.topSky, b.topSky, t)!,
      bottomSky: Color.lerp(a.bottomSky, b.bottomSky, t)!,
      sunColor: Color.lerp(a.sunColor, b.sunColor, t)!,
      sunOpacity: _lerpD(a.sunOpacity, b.sunOpacity, t),
      moonOpacity: _lerpD(a.moonOpacity, b.moonOpacity, t),
      starOpacity: _lerpD(a.starOpacity, b.starOpacity, t),
      atmosphereColor: Color.lerp(a.atmosphereColor, b.atmosphereColor, t)!,
      atmosphereAlpha: _lerpD(a.atmosphereAlpha, b.atmosphereAlpha, t),
    );
  }

  static double _lerpD(double a, double b, double t) => a + (b - a) * t;
}

const Phase _dayPhase = Phase(
  topSky: Color(0xFF5BAEEA),
  bottomSky: Color(0xFFC9E8F2),
  sunColor: Color(0xFFFFE066),
  sunOpacity: 1.0,
  moonOpacity: 0.0,
  starOpacity: 0.0,
  atmosphereColor: Color(0x00000000),
  atmosphereAlpha: 0.0,
);

const Phase _sunsetPhase = Phase(
  topSky: Color(0xFF52359F),
  // 짙은 보라
  bottomSky: Color(0xFFFFA262),
  // 주황 지평선
  sunColor: Color(0xFFFF8A40),
  // 주황 해
  sunOpacity: 1.0,
  moonOpacity: 0.0,
  starOpacity: 0.0,
  atmosphereColor: Color(0xFFFF6633),
  atmosphereAlpha: 0.18,
);

const Phase _nightPhase = Phase(
  topSky: Color(0xFF0A1228),
  // 짙은 남색
  bottomSky: Color(0xFF1C2F58),
  sunColor: Color(0xFFFFE066),
  sunOpacity: 0.0,
  moonOpacity: 1.0,
  starOpacity: 1.0,
  atmosphereColor: Color(0xFF0A1228),
  atmosphereAlpha: 0.45,
);

const Phase _dawnPhase = Phase(
  topSky: Color(0xFF6B4DAA),
  // 보랏빛 새벽
  bottomSky: Color(0xFFFFB8AA),
  // 분홍 지평선
  sunColor: Color(0xFFFFA8B0),
  // 떠오르는 분홍 해
  sunOpacity: 0.6,
  moonOpacity: 0.3,
  starOpacity: 0.3,
  atmosphereColor: Color(0xFFCC6688),
  atmosphereAlpha: 0.15,
);

const List<Phase> _phases = [
  _dayPhase,
  _sunsetPhase,
  _nightPhase,
  _dawnPhase,
];

// 사이클 한 바퀴 점수. ~3분 정도면 한 사이클 도는 페이스.
const double _cycleScore = 1000.0;

/// score를 받아 현재 페이즈를 보간 계산.
Phase currentPhase(double score) {
  final cycleT = (score % _cycleScore) / _cycleScore;
  final pf = cycleT * _phases.length;
  final i = pf.floor() % _phases.length;
  final localT = pf - pf.floor();
  // smoothstep으로 "잠깐 머무르다 빠르게 전환" 느낌
  final smoothT = localT * localT * (3 - 2 * localT);
  return Phase.lerp(_phases[i], _phases[(i + 1) % _phases.length], smoothT);
}

// ─────────────────────────────────────────────────────────────
// 패럴랙스 기본 클래스
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// 하늘 (페이즈에 따라 색상 변화)
// ─────────────────────────────────────────────────────────────

class SkyLayer extends _ParallaxLayer {
  SkyLayer() : super(speedMultiplier: 0, layerPriority: -100);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final phase = currentPhase(gameRef.score);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [phase.topSky, phase.bottomSky],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }
}

// ─────────────────────────────────────────────────────────────
// 별 (밤에만 보임, 깜빡임 효과)
// ─────────────────────────────────────────────────────────────

class _StarData {
  const _StarData({
    required this.x,
    required this.y,
    required this.size,
    required this.twinkleOffset,
  });

  final double x;
  final double y;
  final double size;
  final double twinkleOffset;
}

class StarLayer extends _ParallaxLayer {
  StarLayer() : super(speedMultiplier: 0.02, layerPriority: -97);

  static const double _patternWidth = 1600;
  static final List<_StarData> _stars = _generateStars();
  double _time = 0;

  static List<_StarData> _generateStars() {
    final rng = Random(123);
    return List.generate(50, (_) {
      return _StarData(
        x: rng.nextDouble() * _patternWidth,
        y: 10 + rng.nextDouble() * 220,
        size: 0.8 + rng.nextDouble() * 1.6,
        twinkleOffset: rng.nextDouble() * 2 * pi,
      );
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final phase = currentPhase(gameRef.score);
    if (phase.starOpacity <= 0.01) return;

    final offset = scrollOffset % _patternWidth;
    for (double xStart = -_patternWidth - offset;
        xStart < size.x + _patternWidth;
        xStart += _patternWidth) {
      for (final s in _stars) {
        final twinkle = (sin(_time * 2 + s.twinkleOffset) + 1) / 2;
        final opacity = phase.starOpacity * (0.4 + 0.6 * twinkle);
        final paint = Paint()
          ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(xStart + s.x, s.y), s.size, paint);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────
// 달 (밤에만 보임)
// ─────────────────────────────────────────────────────────────

class MoonLayer extends _ParallaxLayer {
  MoonLayer() : super(speedMultiplier: 0, layerPriority: -96);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final phase = currentPhase(gameRef.score);
    if (phase.moonOpacity <= 0.01) return;

    final cx = size.x - 90;
    const cy = 90.0;
    final opacity = phase.moonOpacity;

    final glowPaint = Paint()..color = Colors.white.withOpacity(0.15 * opacity);
    final moonPaint = Paint()
      ..color = const Color(0xFFEEEEF8).withOpacity(opacity);
    final craterPaint = Paint()
      ..color = const Color(0xFFB8B8C8).withOpacity(opacity);

    canvas.drawCircle(Offset(cx, cy), 50, glowPaint);
    canvas.drawCircle(Offset(cx, cy), 30, moonPaint);
    // 분화구 디테일
    canvas.drawCircle(Offset(cx - 8, cy - 6), 4, craterPaint);
    canvas.drawCircle(Offset(cx + 6, cy + 4), 3, craterPaint);
    canvas.drawCircle(Offset(cx - 3, cy + 9), 2.5, craterPaint);
  }
}

// ─────────────────────────────────────────────────────────────
// 해 (낮/노을/새벽에 보임, 색상 페이즈에 따라 변화)
// ─────────────────────────────────────────────────────────────

class SunLayer extends _ParallaxLayer {
  SunLayer() : super(speedMultiplier: 0, layerPriority: -95);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final phase = currentPhase(gameRef.score);
    if (phase.sunOpacity <= 0.01) return;

    final cx = size.x - 90;
    const cy = 90.0;
    final op = phase.sunOpacity;
    final sun = phase.sunColor;

    final glowPaint = Paint()..color = sun.withOpacity(0.25 * op);
    final midGlowPaint = Paint()..color = sun.withOpacity(0.45 * op);
    final sunPaint = Paint()..color = sun.withOpacity(op);

    canvas.drawCircle(Offset(cx, cy), 60, glowPaint);
    canvas.drawCircle(Offset(cx, cy), 45, midGlowPaint);
    canvas.drawCircle(Offset(cx, cy), 32, sunPaint);
  }
}

// ─────────────────────────────────────────────────────────────
// 먼 산
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// 구름
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// 가까운 언덕
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// 분위기 오버레이 — 모든 배경 레이어 위에 페이즈 색상을 살짝 덧칠하여
// 풍경 전체가 노을/밤 분위기에 물들도록 함. 땅과 플레이어는 영향 없음.
// ─────────────────────────────────────────────────────────────

class AtmosphereOverlay extends _ParallaxLayer {
  AtmosphereOverlay() : super(speedMultiplier: 0, layerPriority: -50);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final phase = currentPhase(gameRef.score);
    if (phase.atmosphereAlpha <= 0.01) return;
    final paint = Paint()
      ..color = phase.atmosphereColor.withOpacity(phase.atmosphereAlpha);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }
}
