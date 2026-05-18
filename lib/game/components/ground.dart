import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../runner_game.dart';

class Ground extends PositionComponent with HasGameRef<RunnerGame> {
  static const double groundHeight = 100.0;
  double scrollOffset = 0.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2(gameRef.size.x, groundHeight);
    position = Vector2(0, gameRef.size.y - groundHeight);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = Vector2(size.x, groundHeight);
    position = Vector2(0, size.y - groundHeight);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 게임이 진행 중일 때만 바닥을 스크롤 시킵니다.
    if (gameRef.state == GameState.playing) {
      scrollOffset += gameRef.gameSpeed * dt;
      // 무한 루프를 위해 오프셋 리셋
      if (scrollOffset > 150) {
        scrollOffset -= 150;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // 기본 바닥 색상 (잔디색)
    final basePaint = Paint()..color = const Color(0xFF388E3C);
    canvas.drawRect(size.toRect(), basePaint);

    // 바닥이 뒤로 지나가는 속도감을 주기 위한 디테일 (풀/흙 무늬) 그리기
    final detailPaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 화면 전체 폭보다 조금 더 넓게 그려서 스크롤 시 자연스럽게 이어지게 함
    for (double i = -150; i <= size.x + 150; i += 150) {
      final xPos = i - scrollOffset;
      
      // 풀 무늬 1
      canvas.drawLine(Offset(xPos + 30, 20), Offset(xPos + 60, 20), detailPaint);
      // 풀 무늬 2
      canvas.drawLine(Offset(xPos + 90, 60), Offset(xPos + 130, 60), detailPaint);
      // 풀 무늬 3
      canvas.drawLine(Offset(xPos + 10, 80), Offset(xPos + 40, 80), detailPaint);
    }
    
    // 땅과 하늘의 경계선 (테두리)
    final borderPaint = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 6), borderPaint);
  }
}
