import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Constants
const double cellSize = 20.0;
const Color boardBackgroundColor = Color(0xFF0A0E21);
const Color gridColor = Colors.white24;
const Color foodColor = Colors.red;

// Difficulty settings
enum GameDifficulty {
  easy(0.3, 10, "Easy"),
  medium(0.2, 20, "Medium"),
  hard(0.1, 30, "Hard");

  final double moveDelay;
  final int pointsPerFood;
  final String displayName;

  const GameDifficulty(this.moveDelay, this.pointsPerFood, this.displayName);
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slither Dash',
      theme: ThemeData.dark(),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final SlitherDashGame game = SlitherDashGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: boardBackgroundColor,
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (!game.isPaused && !game.isGameOver && game.isRunning) {
              if (details.delta.dy < 0 && game.direction != const Offset(0, 1)) {
                game.nextDirection = const Offset(0, -1);
              } else if (details.delta.dy > 0 && game.direction != const Offset(0, -1)) {
                game.nextDirection = const Offset(0, 1);
              }
            }
          },
          onHorizontalDragUpdate: (details) {
            if (!game.isPaused && !game.isGameOver && game.isRunning) {
              if (details.delta.dx < 0 && game.direction != const Offset(1, 0)) {
                game.nextDirection = const Offset(-1, 0);
              } else if (details.delta.dx > 0 && game.direction != const Offset(-1, 0)) {
                game.nextDirection = const Offset(1, 0);
              }
            }
          },
          child: GameWidget(
            game: game,
            overlayBuilderMap: {
              'MainMenu': (context, game) {
                final slitherGame = game as SlitherDashGame;
                return Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Slither Dash",
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ValueListenableBuilder<int>(
                          valueListenable: slitherGame.highScore,
                          builder: (context, value, _) {
                            return Text(
                              "High Score: $value",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        // Difficulty Selector
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Difficulty",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ValueListenableBuilder<GameDifficulty>(
                                valueListenable: slitherGame.difficulty,
                                builder: (context, currentDifficulty, _) {
                                  return DropdownButton<GameDifficulty>(
                                    value: currentDifficulty,
                                    dropdownColor: Colors.grey[900],
                                    style: const TextStyle(color: Colors.white),
                                    onChanged: (GameDifficulty? newDifficulty) {
                                      if (newDifficulty != null) {
                                        slitherGame.changeDifficulty(newDifficulty);
                                      }
                                    },
                                    items: GameDifficulty.values.map((difficulty) {
                                      return DropdownMenuItem<GameDifficulty>(
                                        value: difficulty,
                                        child: Text(
                                          difficulty.displayName,
                                          style: TextStyle(
                                            color: _getDifficultyColor(difficulty),
                                            fontWeight: currentDifficulty == difficulty 
                                                ? FontWeight.bold 
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              ValueListenableBuilder<GameDifficulty>(
                                valueListenable: slitherGame.difficulty,
                                builder: (context, difficulty, _) {
                                  return Text(
                                    "Speed: ${(1/difficulty.moveDelay).toStringAsFixed(1)}x | Points: ${difficulty.pointsPerFood}",
                                    style: TextStyle(
                                      color: _getDifficultyColor(difficulty),
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () {
                            slitherGame.startGame();
                            slitherGame.overlays.remove('MainMenu');
                            slitherGame.overlays.addAll(['Score', 'PauseButton']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                          child: const Text(
                            "Start Game",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              'Score': (context, game) {
                final slitherGame = game as SlitherDashGame;
                return Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 30),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: slitherGame.score,
                          builder: (context, value, _) {
                            return Text(
                              "Score: $value",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        ValueListenableBuilder<GameDifficulty>(
                          valueListenable: slitherGame.difficulty,
                          builder: (context, difficulty, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getDifficultyColor(difficulty).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                difficulty.displayName,
                                style: TextStyle(
                                  color: _getDifficultyColor(difficulty),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              'PauseButton': (context, game) {
                final slitherGame = game as SlitherDashGame;
                return Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 30, right: 16),
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.black54,
                      onPressed: () {
                        slitherGame.pauseGame();
                        slitherGame.overlays.remove('PauseButton');
                        slitherGame.overlays.add('PauseMenu');
                      },
                      child: const Icon(Icons.pause, color: Colors.white),
                    ),
                  ),
                );
              },
              'PauseMenu': (context, game) {
                final slitherGame = game as SlitherDashGame;
                return Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Paused",
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<GameDifficulty>(
                          valueListenable: slitherGame.difficulty,
                          builder: (context, difficulty, _) {
                            return Text(
                              "Difficulty: ${difficulty.displayName}",
                              style: TextStyle(
                                color: _getDifficultyColor(difficulty),
                                fontSize: 18,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            slitherGame.resumeGame();
                            slitherGame.overlays.remove('PauseMenu');
                            slitherGame.overlays.add('PauseButton');
                          },
                          child: const Text("Resume"),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            slitherGame.resetGame();
                            slitherGame.overlays.remove('PauseMenu');
                            slitherGame.overlays.add('PauseButton');
                          },
                          child: const Text("Restart"),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            slitherGame.quitToMenu();
                          },
                          child: const Text("Quit to Main Menu"),
                        ),
                      ],
                    ),
                  ),
                );
              },
              'GameOver': (context, game) {
                final slitherGame = game as SlitherDashGame;
                return Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Game Over",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Final Score: ${slitherGame.score.value}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<GameDifficulty>(
                          valueListenable: slitherGame.difficulty,
                          builder: (context, difficulty, _) {
                            return Text(
                              "Difficulty: ${difficulty.displayName}",
                              style: TextStyle(
                                color: _getDifficultyColor(difficulty),
                                fontSize: 16,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<int>(
                          valueListenable: slitherGame.highScore,
                          builder: (context, value, _) {
                            return Text(
                              "High Score: $value",
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            slitherGame.resetGame();
                            slitherGame.overlays.remove('GameOver');
                            slitherGame.overlays.addAll(['Score', 'PauseButton']);
                          },
                          child: const Text("Restart"),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            slitherGame.quitToMenu();
                          },
                          child: const Text("Quit to Main Menu"),
                        ),
                      ],
                    ),
                  ),
                );
              },
            },
            initialActiveOverlays: const ['MainMenu'],
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return Colors.green;
      case GameDifficulty.medium:
        return Colors.orange;
      case GameDifficulty.hard:
        return Colors.red;
    }
  }
}

class SlitherDashGame extends FlameGame {
  late List<Offset> snake;
  late Offset food;

  Offset direction = const Offset(1, 0);
  Offset nextDirection = const Offset(1, 0);

  double moveTimer = 0;
  double moveDelay = GameDifficulty.medium.moveDelay;

  final Random random = Random();
  ValueNotifier<int> score = ValueNotifier<int>(0);
  ValueNotifier<int> highScore = ValueNotifier<int>(0);
  ValueNotifier<GameDifficulty> difficulty = ValueNotifier<GameDifficulty>(GameDifficulty.medium);
  bool isGameOver = false;
  bool isPaused = false;
  bool isRunning = false;

  int rows = 0;
  int cols = 0;
  double offsetX = 0;
  double offsetY = 0;

  // Smooth positions
  late List<Offset> smoothSnake;
  double lerpProgress = 0;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    calculateGrid();
    await loadHighScore();
  }

  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    highScore.value = prefs.getInt('high_score') ?? 0;
  }

  Future<void> saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('high_score', highScore.value);
  }

  void changeDifficulty(GameDifficulty newDifficulty) {
    difficulty.value = newDifficulty;
    moveDelay = newDifficulty.moveDelay;
    
    // If game is running, apply the new speed immediately
    if (isRunning && !isPaused && !isGameOver) {
      lerpProgress = 0; // Reset interpolation for smooth transition
    }
  }

  void calculateGrid() {
    rows = (size.y / cellSize).floor();
    cols = (size.x / cellSize).floor();

    final boardWidth = cols * cellSize;
    final boardHeight = rows * cellSize;

    offsetX = (size.x - boardWidth) / 2;
    offsetY = (size.y - boardHeight) / 2;
  }

  void startGame() {
    resetGame();
    isRunning = true;
  }

  void resetGame() {
    calculateGrid();
    snake = [Offset((cols / 2).floorToDouble(), (rows / 2).floorToDouble())];
    smoothSnake = List.from(snake);
    direction = const Offset(1, 0);
    nextDirection = const Offset(1, 0);
    score.value = 0;
    isGameOver = false;
    isPaused = false;
    lerpProgress = 0;
    spawnFood();
  }

  void quitToMenu() {
    isRunning = false;
    isGameOver = false;
    isPaused = false;
    overlays.clear();
    overlays.add('MainMenu');
  }

  void spawnFood() {
    // Ensure food doesn't spawn on snake
    while (true) {
      final newFood = Offset(
        random.nextInt(cols).toDouble(),
        random.nextInt(rows).toDouble(),
      );
      if (!snake.contains(newFood)) {
        food = newFood;
        break;
      }
    }
  }

  @override
  Color backgroundColor() => boardBackgroundColor;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!isRunning || isGameOver) return;

    final gridPaint = Paint()..color = gridColor.withOpacity(0.2);

    // Draw grid
    for (int row = 0; row <= rows; row++) {
      canvas.drawLine(
          Offset(offsetX, offsetY + row * cellSize),
          Offset(offsetX + cols * cellSize, offsetY + row * cellSize),
          gridPaint);
    }
    for (int col = 0; col <= cols; col++) {
      canvas.drawLine(
          Offset(offsetX + col * cellSize, offsetY),
          Offset(offsetX + col * cellSize, offsetY + rows * cellSize),
          gridPaint);
    }

    // Draw snake with smooth movement
    for (int i = 0; i < smoothSnake.length; i++) {
      final part = smoothSnake[i];
      final isHead = i == 0;

      final rect = Rect.fromLTWH(
          offsetX + part.dx * cellSize,
          offsetY + part.dy * cellSize,
          cellSize,
          cellSize);

      final paint = Paint()
        ..shader = LinearGradient(
          colors: isHead
              ? [Colors.lightGreenAccent, Colors.greenAccent]
              : [Colors.green, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);

      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cellSize / 4)), paint);

      if (isHead) {
        final eyePaint = Paint()..color = Colors.black;
        final eyeOffset = cellSize * 0.2;
        final eyeRadius = cellSize * 0.1;
        
        // Draw eyes based on direction
        final leftEye = direction == const Offset(1, 0) || direction == const Offset(-1, 0)
            ? Offset(rect.left + eyeOffset, rect.top + eyeOffset)
            : Offset(rect.left + eyeOffset, rect.top + eyeOffset);
        final rightEye = direction == const Offset(1, 0) || direction == const Offset(-1, 0)
            ? Offset(rect.left + cellSize - eyeOffset, rect.top + eyeOffset)
            : Offset(rect.left + cellSize - eyeOffset, rect.top + eyeOffset);
            
        canvas.drawCircle(leftEye, eyeRadius, eyePaint);
        canvas.drawCircle(rightEye, eyeRadius, eyePaint);
      }
    }

    // Draw food with difficulty-based color
    final foodPaint = Paint()..color = _getDifficultyColor(difficulty.value);
    final foodRect = Rect.fromLTWH(
        offsetX + food.dx * cellSize,
        offsetY + food.dy * cellSize,
        cellSize,
        cellSize);
    canvas.drawRect(foodRect, foodPaint);
    
    // Add a shine effect to food
    final shinePaint = Paint()..color = Colors.white.withOpacity(0.3);
    canvas.drawCircle(
      Offset(foodRect.left + cellSize * 0.3, foodRect.top + cellSize * 0.3),
      cellSize * 0.15,
      shinePaint,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning || isGameOver || isPaused) return;

    lerpProgress += dt / moveDelay;
    if (lerpProgress >= 1) {
      lerpProgress = 0;
      moveSnake();
    } else {
      // Interpolate smoothSnake between current and next positions
      for (int i = 0; i < snake.length; i++) {
        final current = smoothSnake[i];
        final target = snake[i];
        smoothSnake[i] = Offset(
          current.dx + (target.dx - current.dx) * lerpProgress,
          current.dy + (target.dy - current.dy) * lerpProgress,
        );
      }
    }
  }

  void moveSnake() {
    direction = nextDirection;

    final newHead = snake.first + direction;

    if (newHead.dx < 0 ||
        newHead.dy < 0 ||
        newHead.dx >= cols ||
        newHead.dy >= rows ||
        snake.contains(newHead)) {
      isGameOver = true;
      if (score.value > highScore.value) {
        highScore.value = score.value;
        saveHighScore();
      }
      overlays.remove('Score');
      overlays.remove('PauseButton');
      overlays.add('GameOver');
      return;
    }

    snake.insert(0, newHead);
    smoothSnake = List.from(snake);

    if (newHead == food) {
      score.value += difficulty.value.pointsPerFood;
      spawnFood();
    } else {
      snake.removeLast();
    }
  }

  void pauseGame() => isPaused = true;

  void resumeGame() => isPaused = false;

  Color _getDifficultyColor(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return Colors.green;
      case GameDifficulty.medium:
        return Colors.orange;
      case GameDifficulty.hard:
        return Colors.red;
    }
  }
}