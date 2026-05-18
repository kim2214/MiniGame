import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../runner_game.dart';

class PlayerShadow extends Component with HasGameRef<RunnerGame> {
  static const double _baseWidth = 70;
  static const double _baseHeight = 12;
  static const double _maxHeight = 200;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final player = gameRef.player;
    if (!player.isMounted) return;

    final groundY = gameRef.size.y - 100.0;
    // Player anchor=bottomCenter이므로 position.y는 발끝
    final heightAboveGround =
        (groundY - player.position.y).clamp(0.0, _maxHeight);

    // 점프할수록 작아지고 투명해짐
    final shrink = (1.0 - heightAboveGround / 400.0).clamp(0.4, 1.0);
    final w = _baseWidth * shrink;
    final h = _baseHeight * shrink;
    final opacity =
        (0.45 * (1 - heightAboveGround / 300.0)).clamp(0.08, 0.45);

    final paint = Paint()..color = Colors.black.withOpacity(opacity);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(player.position.x, groundY - 2),
        width: w,
        height: h,
      ),
      paint,
    );
  }
}
