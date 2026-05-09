import 'dart:math';

import 'package:flame/components.dart';

import '../components/obstacle.dart';
import '../runner_game.dart';

class ObstacleManager extends Component with HasGameRef<RunnerGame> {
  double timer = 0;
  double spawnInterval = 1.5; // Spawn an obstacle every 1.5 seconds initially
  final random = Random();

  @override
  void update(double dt) {
    super.update(dt);

    if (gameRef.isGameOver) return;

    timer += dt;
    
    // Adjust spawn rate based on game speed to keep it challenging but fair
    double currentInterval = spawnInterval * (300.0 / gameRef.gameSpeed);
    
    // Cap the minimum interval so it doesn't get impossible
    if (currentInterval < 0.7) {
      currentInterval = 0.7;
    }

    if (timer >= currentInterval) {
      timer = 0;
      spawnObstacle();
    }
  }

  void spawnObstacle() {
    final obstacle = Obstacle();
    gameRef.add(obstacle);
  }

  void reset() {
    timer = 0;
    // Remove all existing obstacles
    gameRef.children.whereType<Obstacle>().forEach((obstacle) {
      obstacle.removeFromParent();
    });
  }
}
