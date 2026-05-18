import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../runner_game.dart';
import 'player.dart';

class Obstacle extends SpriteComponent with HasGameRef<RunnerGame>, CollisionCallbacks {
  static const double obstacleSize = 64.0; // 플레이어(80)보다 살짝 작게
  static const double groundEmbed = 6.0; // 이미지 바닥 투명 여백만큼 땅에 살짝 박아 부유감 제거

  Obstacle() : super(size: Vector2.all(obstacleSize), anchor: Anchor.bottomCenter);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    sprite = Sprite(gameRef.images.fromCache('obstacle.png'));

    final groundY = gameRef.size.y - 100.0;
    // bottomCenter 앵커: position은 발끝 중앙 좌표. 화면 오른쪽 바깥에서 등장하도록 +size/2.
    // groundEmbed만큼 아래로 내려 이미지 바닥 패딩을 땅에 묻어 부유감 제거.
    position = Vector2(gameRef.size.x + obstacleSize / 2, groundY + groundEmbed);

    // hitbox는 부모의 size 박스 기준 좌상단 상대 좌표 (앵커와 무관).
    // 타이트하게 크롭된 이미지 기준: 선인장 본체만 잡고 바닥의 흙 받침은 제외.
    add(RectangleHitbox(
      size: Vector2(obstacleSize * 0.55, obstacleSize * 0.75),
      position: Vector2(obstacleSize * 0.225, obstacleSize * 0.08),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Move left
    position.x -= gameRef.gameSpeed * dt;

    // Remove when it goes off screen (앵커가 bottomCenter이므로 절반만큼 더 나가야 완전히 사라짐)
    if (position.x < -obstacleSize / 2) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    // If the obstacle hits the player, trigger Game Over
    if (other is Player) {
      gameRef.gameOver();
    }
  }
}
