import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../runner_game.dart';
import 'player.dart';

class FlyingObstacle extends SpriteAnimationComponent
    with HasGameRef<RunnerGame>, CollisionCallbacks {
  // 큰 박쥐 — 자연스러운 비율을 위해 가로 90, 세로 140.
  // bat.png 원본 한 프레임은 101×353. 위/아래 여백을 srcPosition으로 잘라
  // 박쥐 본체 영역(101×230)을 90×140에 매핑 → 가로 약간만 늘어남, 세로 압축 크게 줄어듦.
  static const double batWidth = 90.0;
  static const double batHeight = 140.0;
  // 박쥐 발끝이 땅에서 떨어진 높이. 슬라이드 hitbox 위에 위치해야 슬라이드로 회피 가능.
  static const double bottomAboveGround = 52.0;

  FlyingObstacle()
      : super(
          size: Vector2(batWidth, batHeight),
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final batImage = gameRef.images.fromCache('bat.png');
    // 707/7 = 101 (정수). 7프레임.
    final frameWidth = (batImage.width / 7).floorToDouble();
    // 박쥐 본체가 자리한 세로 범위만 잘라 사용 (위/아래 빈 공간 제거).
    const double cropTop = 20;
    const double cropHeight = 230;

    final sprites = List.generate(7, (i) {
      return Sprite(
        batImage,
        srcPosition: Vector2(i * frameWidth, cropTop),
        srcSize: Vector2(frameWidth, cropHeight),
      );
    });
    animation = SpriteAnimation.spriteList(
      sprites,
      stepTime: 0.08,
    );

    final groundY = gameRef.size.y - 100.0;
    position = Vector2(
      gameRef.size.x + batWidth / 2,
      groundY - bottomAboveGround,
    );

    // hitbox는 박쥐 본체 중심부 (날개 끝은 제외).
    // 박스 가로 22~78% / 세로 50~93% 위치 — 본체 영역 + 하단까지 포함하여
    // 달리기 hitbox(groundY-72 ~ groundY-8)와 겹치도록.
    add(RectangleHitbox(
      size: Vector2(batWidth * 0.55, batHeight * 0.43),
      position: Vector2(batWidth * 0.225, batHeight * 0.5),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= gameRef.gameSpeed * dt;
    if (position.x < -batWidth / 2) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      HapticFeedback.heavyImpact();
      gameRef.gameOver();
    }
  }
}
