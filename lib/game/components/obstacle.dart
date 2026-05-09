import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../runner_game.dart';
import 'player.dart';

class Obstacle extends SpriteComponent with HasGameRef<RunnerGame>, CollisionCallbacks {
  static const double obstacleSize = 50.0;

  Obstacle() : super(size: Vector2.all(obstacleSize));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    sprite = Sprite(gameRef.images.fromCache('obstacle.png'));

    final groundY = gameRef.size.y - 100.0;
    position = Vector2(gameRef.size.x, groundY - obstacleSize);

    add(RectangleHitbox(
      size: Vector2(obstacleSize * 0.7, obstacleSize * 0.7),
      position: Vector2(obstacleSize * 0.15, obstacleSize * 0.3), // hitbox slightly shifted down
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Move left
    position.x -= gameRef.gameSpeed * dt;

    // Remove when it goes off screen
    if (position.x < -obstacleSize) {
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
