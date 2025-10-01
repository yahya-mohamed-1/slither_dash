import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Constants - Reduced cell size for smaller grid and snake
const double cellSize = 15.0;
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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Request focus when the screen loads to capture keyboard events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: boardBackgroundColor,
      body: SafeArea(
        child: RawKeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKey: (RawKeyEvent event) {
            game.handleKeyEvent(event);
          },
          child: Stack(
            children: [
              // Game widget takes full screen
              GestureDetector(
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
                                  slitherGame.overlays.add('PauseButton');
                                  // Re-request focus when starting game
                                  _focusNode.requestFocus();
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
                              const SizedBox(height: 20),
                              // Keyboard controls hint
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Controls",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Arrow Keys or WASD\nSwipe to change direction",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
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
                                  // Re-request focus when resuming game
                                  _focusNode.requestFocus();
                                },
                                child: const Text("Resume"),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  slitherGame.resetGame();
                                  slitherGame.overlays.remove('PauseMenu');
                                  slitherGame.overlays.add('PauseButton');
                                  // Re-request focus when restarting game
                                  _focusNode.requestFocus();
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
                                  slitherGame.overlays.add('PauseButton');
                                  // Re-request focus when restarting game
                                  _focusNode.requestFocus();
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
              
              // Custom Score Display - Top Left Corner
              ValueListenableBuilder<bool>(
                valueListenable: game.isRunningNotifier,
                builder: (context, isRunning, _) {
                  if (!isRunning || game.isGameOver || game.isPaused) {
                    return const SizedBox.shrink();
                  }
                  return ValueListenableBuilder<bool>(
                    valueListenable: game.showScoreOverlay,
                    builder: (context, showScore, _) {
                      if (!showScore) return const SizedBox.shrink();
                      return Positioned(
                        top: 30,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.greenAccent, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Score
                              ValueListenableBuilder<int>(
                                valueListenable: game.score,
                                builder: (context, scoreValue, _) {
                                  return Text(
                                    "SCORE: $scoreValue",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              // Difficulty Badge
                              ValueListenableBuilder<GameDifficulty>(
                                valueListenable: game.difficulty,
                                builder: (context, currentDifficulty, _) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getDifficultyColor(currentDifficulty).withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      currentDifficulty.displayName.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
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
                  );
                },
              ),

              // High Score Display - Top Right Corner (when not showing pause button)
              ValueListenableBuilder<bool>(
                valueListenable: game.isRunningNotifier,
                builder: (context, isRunning, _) {
                  if (!isRunning || game.isGameOver || game.isPaused) {
                    return const SizedBox.shrink();
                  }
                  return ValueListenableBuilder<bool>(
                    valueListenable: game.showHighScoreOverlay,
                    builder: (context, showHighScore, _) {
                      if (!showHighScore) return const SizedBox.shrink();
                      return Positioned(
                        top: 30,
                        right: 70, // Leave space for pause button
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ValueListenableBuilder<int>(
                            valueListenable: game.highScore,
                            builder: (context, highScoreValue, _) {
                              return Text(
                                "BEST: $highScoreValue",
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // Food Counter - Bottom Left Corner
              ValueListenableBuilder<bool>(
                valueListenable: game.isRunningNotifier,
                builder: (context, isRunning, _) {
                  if (!isRunning || game.isGameOver || game.isPaused) {
                    return const SizedBox.shrink();
                  }
                  return ValueListenableBuilder<bool>(
                    valueListenable: game.showFoodCounterOverlay,
                    builder: (context, showFoodCounter, _) {
                      if (!showFoodCounter) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 30,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getDifficultyColor(game.difficulty.value),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ValueListenableBuilder<GameDifficulty>(
                                valueListenable: game.difficulty,
                                builder: (context, difficulty, _) {
                                  return Text(
                                    "+${difficulty.pointsPerFood}",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // Speed Indicator - Bottom Right Corner
              ValueListenableBuilder<bool>(
                valueListenable: game.isRunningNotifier,
                builder: (context, isRunning, _) {
                  if (!isRunning || game.isGameOver || game.isPaused) {
                    return const SizedBox.shrink();
                  }
                  return ValueListenableBuilder<bool>(
                    valueListenable: game.showSpeedOverlay,
                    builder: (context, showSpeed, _) {
                      if (!showSpeed) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 30,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.speed,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              ValueListenableBuilder<GameDifficulty>(
                                valueListenable: game.difficulty,
                                builder: (context, difficulty, _) {
                                  return Text(
                                    "${(1/difficulty.moveDelay).toStringAsFixed(1)}x",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
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

// Core Game Logic
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
  ValueNotifier<bool> isRunningNotifier = ValueNotifier<bool>(false);
  
  // Overlay visibility controllers
  ValueNotifier<bool> showScoreOverlay = ValueNotifier<bool>(true);
  ValueNotifier<bool> showHighScoreOverlay = ValueNotifier<bool>(true);
  ValueNotifier<bool> showFoodCounterOverlay = ValueNotifier<bool>(true);
  ValueNotifier<bool> showSpeedOverlay = ValueNotifier<bool>(true);
  
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

  // Track food position relative to overlays
  bool _foodUnderScoreOverlay = false;
  bool _foodUnderHighScoreOverlay = false;
  bool _foodUnderFoodCounterOverlay = false;
  bool _foodUnderSpeedOverlay = false;

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
    isRunningNotifier.value = true;
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
    
    // Reset all overlay visibility
    showScoreOverlay.value = true;
    showHighScoreOverlay.value = true;
    showFoodCounterOverlay.value = true;
    showSpeedOverlay.value = true;
    
    _foodUnderScoreOverlay = false;
    _foodUnderHighScoreOverlay = false;
    _foodUnderFoodCounterOverlay = false;
    _foodUnderSpeedOverlay = false;
    
    spawnFood();
  }

  void quitToMenu() {
    isRunning = false;
    isRunningNotifier.value = false;
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
    
    // Check if food is under any overlay and hide that overlay
    _checkFoodOverlap();
  }

  void _checkFoodOverlap() {
    // Define overlay regions (approximate positions)
    final foodScreenX = offsetX + food.dx * cellSize;
    final foodScreenY = offsetY + food.dy * cellSize;
    
    // Score overlay region (top left)
    final scoreRegion = Rect.fromLTWH(0, 0, 200, 60);
    // High score overlay region (top right)
    final highScoreRegion = Rect.fromLTWH(size.x - 150, 0, 150, 50);
    // Food counter overlay region (bottom left)
    final foodCounterRegion = Rect.fromLTWH(0, size.y - 60, 120, 60);
    // Speed overlay region (bottom right)
    final speedRegion = Rect.fromLTWH(size.x - 120, size.y - 60, 120, 60);
    
    // Check if food overlaps with any overlay region
    final foodRect = Rect.fromLTWH(foodScreenX, foodScreenY, cellSize, cellSize);
    
    _foodUnderScoreOverlay = foodRect.overlaps(scoreRegion);
    _foodUnderHighScoreOverlay = foodRect.overlaps(highScoreRegion);
    _foodUnderFoodCounterOverlay = foodRect.overlaps(foodCounterRegion);
    _foodUnderSpeedOverlay = foodRect.overlaps(speedRegion);
    
    // Update overlay visibility
    showScoreOverlay.value = !_foodUnderScoreOverlay;
    showHighScoreOverlay.value = !_foodUnderHighScoreOverlay;
    showFoodCounterOverlay.value = !_foodUnderFoodCounterOverlay;
    showSpeedOverlay.value = !_foodUnderSpeedOverlay;
  }

  void _checkFoodEaten() {
    // If food was eaten and it was under an overlay, show that overlay again
    if (_foodUnderScoreOverlay) {
      showScoreOverlay.value = true;
      _foodUnderScoreOverlay = false;
    }
    if (_foodUnderHighScoreOverlay) {
      showHighScoreOverlay.value = true;
      _foodUnderHighScoreOverlay = false;
    }
    if (_foodUnderFoodCounterOverlay) {
      showFoodCounterOverlay.value = true;
      _foodUnderFoodCounterOverlay = false;
    }
    if (_foodUnderSpeedOverlay) {
      showSpeedOverlay.value = true;
      _foodUnderSpeedOverlay = false;
    }
  }

  // Handle keyboard input
  void handleKeyEvent(RawKeyEvent event) {
    if (!isRunning || isGameOver || isPaused) return;

    if (event is RawKeyDownEvent) {
      final logicalKey = event.logicalKey;

      // Arrow keys
      if (logicalKey == LogicalKeyboardKey.arrowUp && direction != const Offset(0, 1)) {
        nextDirection = const Offset(0, -1);
      } else if (logicalKey == LogicalKeyboardKey.arrowDown && direction != const Offset(0, -1)) {
        nextDirection = const Offset(0, 1);
      } else if (logicalKey == LogicalKeyboardKey.arrowLeft && direction != const Offset(1, 0)) {
        nextDirection = const Offset(-1, 0);
      } else if (logicalKey == LogicalKeyboardKey.arrowRight && direction != const Offset(-1, 0)) {
        nextDirection = const Offset(1, 0);
      }
      // WASD keys
      else if (logicalKey == LogicalKeyboardKey.keyW && direction != const Offset(0, 1)) {
        nextDirection = const Offset(0, -1);
      } else if (logicalKey == LogicalKeyboardKey.keyS && direction != const Offset(0, -1)) {
        nextDirection = const Offset(0, 1);
      } else if (logicalKey == LogicalKeyboardKey.keyA && direction != const Offset(1, 0)) {
        nextDirection = const Offset(-1, 0);
      } else if (logicalKey == LogicalKeyboardKey.keyD && direction != const Offset(-1, 0)) {
        nextDirection = const Offset(1, 0);
      }
    }
  }

  @override
  Color backgroundColor() => boardBackgroundColor;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!isRunning || isGameOver) return;

    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.2)
      ..strokeWidth = 0.5; // Thinner grid lines

    // Draw grid with thinner lines
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

    // Draw snake with smaller size and smooth movement
    for (int i = 0; i < smoothSnake.length; i++) {
      final part = smoothSnake[i];
      final isHead = i == 0;

      // Reduced padding for smaller snake segments
      final padding = isHead ? 1.0 : 1.5;
      final segmentSize = cellSize - padding * 2;

      final rect = Rect.fromLTWH(
          offsetX + part.dx * cellSize + padding,
          offsetY + part.dy * cellSize + padding,
          segmentSize,
          segmentSize);

      final paint = Paint()
        ..shader = LinearGradient(
          colors: isHead
              ? [Colors.lightGreenAccent, Colors.greenAccent]
              : [Colors.green, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);

      // Smaller border radius for smaller segments
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(segmentSize / 6)), paint);

      if (isHead) {
        final eyePaint = Paint()..color = Colors.black;
        final eyeOffset = segmentSize * 0.2;
        final eyeRadius = segmentSize * 0.1;
        
        // Draw eyes based on direction
        final leftEye = direction == const Offset(1, 0) || direction == const Offset(-1, 0)
            ? Offset(rect.left + eyeOffset, rect.top + eyeOffset)
            : Offset(rect.left + eyeOffset, rect.top + eyeOffset);
        final rightEye = direction == const Offset(1, 0) || direction == const Offset(-1, 0)
            ? Offset(rect.left + segmentSize - eyeOffset, rect.top + eyeOffset)
            : Offset(rect.left + segmentSize - eyeOffset, rect.top + eyeOffset);
            
        canvas.drawCircle(leftEye, eyeRadius, eyePaint);
        canvas.drawCircle(rightEye, eyeRadius, eyePaint);
      }
    }

    // Draw food with smaller size and difficulty-based color
    final foodPadding = 2.0; // Reduced food size
    final foodSize = cellSize - foodPadding * 2;
    final foodPaint = Paint()..color = _getDifficultyColor(difficulty.value);
    final foodRect = Rect.fromLTWH(
        offsetX + food.dx * cellSize + foodPadding,
        offsetY + food.dy * cellSize + foodPadding,
        foodSize,
        foodSize);
    
    // Draw food as a circle instead of rectangle for better visibility
    canvas.drawCircle(
      Offset(foodRect.center.dx, foodRect.center.dy),
      foodSize / 2,
      foodPaint,
    );
    
    // Add a smaller shine effect to food
    final shinePaint = Paint()..color = Colors.white.withOpacity(0.4);
    canvas.drawCircle(
      Offset(foodRect.left + foodSize * 0.3, foodRect.top + foodSize * 0.3),
      foodSize * 0.15,
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
      isRunningNotifier.value = false;
      if (score.value > highScore.value) {
        highScore.value = score.value;
        saveHighScore();
      }
      overlays.remove('PauseButton');
      overlays.add('GameOver');
      return;
    }

    snake.insert(0, newHead);
    smoothSnake = List.from(snake);

    if (newHead == food) {
      score.value += difficulty.value.pointsPerFood;
      _checkFoodEaten(); // Show overlays that were hidden due to food
      spawnFood();
    } else {
      snake.removeLast();
    }
  }

  void pauseGame() {
    isPaused = true;
    isRunningNotifier.value = false;
  }

  void resumeGame() {
    isPaused = false;
    isRunningNotifier.value = true;
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