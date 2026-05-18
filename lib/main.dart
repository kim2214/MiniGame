import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/runner_game.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2D Runner Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final RunnerGame _game;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _game = RunnerGame();
    _lifecycleListener = AppLifecycleListener(
      onInactive: () {
        // 앱이 포그라운드를 벗어나는 즉시 일시정지 (전화/알림/앱 스위처 등)
        if (_game.state == GameState.playing) {
          _game.pause();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<RunnerGame>(
        game: _game,
        overlayBuilderMap: {
          'Title': (context, game) => _TitleOverlay(game: game),
          'GameOver': (context, game) => _GameOverOverlay(game: game),
          'AudioControl': (context, game) => _AudioControlOverlay(game: game),
          'PauseControl': (context, game) => _PauseControlOverlay(game: game),
          'Paused': (context, game) => _PausedOverlay(game: game),
        },
      ),
    );
  }
}

class _TitleOverlay extends StatelessWidget {
  const _TitleOverlay({required this.game});

  final RunnerGame game;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: game.startGame,
      child: Container(
        color: Colors.black.withOpacity(0.45),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '2D Runner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Best: ${game.bestScore}',
                style: const TextStyle(
                  color: Colors.yellowAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Tap to Start',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '(탭하면 점프)',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioControlOverlay extends StatelessWidget {
  const _AudioControlOverlay({required this.game});

  final RunnerGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 16,
          left: 16,
          child: SafeArea(
            child: ValueListenableBuilder<bool>(
              valueListenable: game.audio.mutedNotifier,
              builder: (context, muted, _) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: game.audio.toggleMute,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      muted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PauseControlOverlay extends StatelessWidget {
  const _PauseControlOverlay({required this.game});

  final RunnerGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 16,
          left: 72, // 16(padding) + 44(mute btn) + 12(gap)
          child: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: game.pause,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay({required this.game});

  final RunnerGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Score: ${game.displayScore}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: game.resume,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: game.resetGame,
              child: const Text('Restart', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.game});

  final RunnerGame game;

  @override
  Widget build(BuildContext context) {
    final score = game.displayScore;
    final isNewBest = score >= game.bestScore && score > 0;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Game Over!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Score: $score',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isNewBest ? 'New Best!' : 'Best: ${game.bestScore}',
              style: TextStyle(
                color: isNewBest ? Colors.orangeAccent : Colors.yellowAccent,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: game.resetGame,
              child: const Text(
                'Restart',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
