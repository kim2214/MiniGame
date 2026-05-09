import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/ground.dart';
import 'components/player.dart';
import 'managers/obstacle_manager.dart';

class RunnerGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  late Player player;
  late ObstacleManager obstacleManager;

  int score = 0;
  bool isGameOver = false;
  double gameSpeed = 300.0; // Pixels per second

  @override
  Color backgroundColor() => const Color(0xFF87CEEB); // Sky blue color

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load images into cache
    await images.loadAll(['run.png', 'jump.png', 'obstacle.png']);

    // Add ground
    add(Ground());

    // Add player
    player = Player();
    add(player);

    // Add obstacle manager
    obstacleManager = ObstacleManager();
    add(obstacleManager);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (isGameOver) {
      resetGame();
    } else {
      player.jump();
    }
  }

  void gameOver() {
    isGameOver = true;
    pauseEngine();
    // We can use overlays to show the Game Over screen later
    overlays.add('GameOver');
  }

  void resetGame() {
    isGameOver = false;
    score = 0;
    gameSpeed = 300.0;
    
    // Reset components
    obstacleManager.reset();
    player.reset();
    
    overlays.remove('GameOver');
    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isGameOver) {
      // Score increases over time
      score++;
      // Speed increases slightly over time
      gameSpeed += 5 * dt;
    }
  }
}
