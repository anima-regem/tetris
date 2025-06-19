import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async' as async;
import 'dart:math';

void main() {
  runApp(
    MaterialApp(
      title: 'Tetris',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0a0a0a),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0a0a0a),
        body: SafeArea(
          child: Column(
            children: [
              // Static title bar
              Container(
                height: 60,
                decoration: const BoxDecoration(color: Color(0xFF1a1a1a)),
                child: const Center(
                  child: Text(
                    'TETRIS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 5,
                    ),
                  ),
                ),
              ),
              // Game area
              Expanded(child: TetrisGameWrapper()),
            ],
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class TetrisGameWrapper extends StatefulWidget {
  const TetrisGameWrapper({super.key});

  @override
  _TetrisGameWrapperState createState() => _TetrisGameWrapperState();
}

class _TetrisGameWrapperState extends State<TetrisGameWrapper> {
  late RetroTetrisGame game;

  @override
  void initState() {
    super.initState();
    game = RetroTetrisGame();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        game.handleTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        game.handleLongPress();
      },
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        final speed = velocity.distance;

        if (speed < 300) return;

        HapticFeedback.selectionClick();
        final dx = velocity.dx;
        final dy = velocity.dy;

        if (dx.abs() > dy.abs()) {
          if (dx > 0) {
            game.handleSwipeRight();
          } else {
            game.handleSwipeLeft();
          }
        } else {
          if (dy > 0) {
            game.handleSwipeDown();
          } else {
            game.handleSwipeUp();
          }
        }
      },
      child: GameWidget(game: game),
    );
  }
}

class RetroTetrisGame extends FlameGame {
  static const int rows = 20;
  static const int cols = 10;
  static const double blockSize = 30;
  static const double borderWidth = 3.0;
  static const double sidePadding = 80.0;

  List<List<bool>> board = List.generate(rows, (_) => List.filled(cols, false));
  List<List<Color?>> boardColors = List.generate(
    rows,
    (_) => List.filled(cols, null),
  );

  Tetromino? piece;
  Tetromino? nextPiece; // Next piece to be spawned
  async.Timer? gameTimer;

  // Game state
  bool isGameStarted = false;
  bool isGamePaused = false;
  bool isGameOver = false;
  int score = 0;
  int level = 1;
  int linesCleared = 0;

  // UI components
  late TextComponent scoreText;
  late TextComponent levelText;
  late TextComponent linesText;
  late TextComponent statusText;
  late TextComponent instructionsText;
  late RectangleComponent gameArea;
  late RectangleComponent gameAreaBorder;

  // Game over overlay components
  late RectangleComponent gameOverOverlay;
  late RectangleComponent gameOverCard;
  late RectangleComponent gameOverCardBorder;
  late TextComponent gameOverText;

  // Next piece preview components
  late RectangleComponent nextPieceArea;
  late RectangleComponent nextPieceAreaBorder;
  late TextComponent nextPieceText;

  @override
  Future<void> onLoad() async {
    final gameAreaWidth = cols * blockSize;
    final gameAreaHeight = rows * blockSize;

    camera.viewfinder.visibleGameSize = Vector2(
      gameAreaWidth +
          sidePadding * 3 +
          150, // Extra space for next piece preview
      gameAreaHeight + 120,
    );

    final gameAreaX = sidePadding * 1.5;
    final gameAreaY = 60.0;

    // Create animated game area background
    gameArea = RectangleComponent(
      position: Vector2(gameAreaX, gameAreaY),
      size: Vector2(gameAreaWidth, gameAreaHeight),
      paint: Paint()..color = const Color(0xFF1a1a1a),
    );
    add(gameArea);

    // Create pulsing game area border
    gameAreaBorder = RectangleComponent(
      position: Vector2(gameAreaX - borderWidth, gameAreaY - borderWidth),
      size: Vector2(
        gameAreaWidth + borderWidth * 2,
        gameAreaHeight + borderWidth * 2,
      ),
      paint:
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth,
    );
    add(gameAreaBorder);

    // Animated score text
    scoreText = TextComponent(
      text: 'SCORE\n0',
      position: Vector2(20, 100),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.2,
          shadows: [
            Shadow(color: Colors.white, blurRadius: 5, offset: Offset(0, 0)),
          ],
        ),
      ),
    );
    add(scoreText);

    levelText = TextComponent(
      text: 'LEVEL\n1',
      position: Vector2(20, 180),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.2,
          shadows: [
            Shadow(color: Colors.white, blurRadius: 5, offset: Offset(0, 0)),
          ],
        ),
      ),
    );
    add(levelText);

    linesText = TextComponent(
      text: 'LINES\n0',
      position: Vector2(20, 260),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.2,
          shadows: [
            Shadow(color: Colors.white, blurRadius: 5, offset: Offset(0, 0)),
          ],
        ),
      ),
    );
    add(linesText);

    instructionsText = TextComponent(
      text:
          'CONTROLS:\n\nTap\nRotate\n\nLong Press\nPause\n\nSwipe Left/Right\nMove\n\nSwipe Down\nDrop',
      position: Vector2(gameAreaX + gameAreaWidth + 20, 100),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
      ),
    );
    add(instructionsText);

    // Next piece preview area
    final nextAreaSize = 120.0;
    final nextAreaX =
        gameAreaX + gameAreaWidth + 10; // Moved closer to game area
    final nextAreaY = 260.0; // Moved up to be more visible

    nextPieceAreaBorder = RectangleComponent(
      position: Vector2(nextAreaX - 2, nextAreaY - 2),
      size: Vector2(nextAreaSize + 4, nextAreaSize + 4),
      paint:
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
    );
    add(nextPieceAreaBorder);

    nextPieceArea = RectangleComponent(
      position: Vector2(nextAreaX, nextAreaY),
      size: Vector2(nextAreaSize, nextAreaSize),
      paint: Paint()..color = const Color(0xFF1a1a1a),
    );
    add(nextPieceArea);

    nextPieceText = TextComponent(
      text: 'NEXT',
      position: Vector2(nextAreaX + nextAreaSize / 2, nextAreaY - 15),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(nextPieceText);

    statusText = TextComponent(
      text: 'TAP TO START',
      position: Vector2(
        gameAreaX + gameAreaWidth / 2,
        gameAreaY + gameAreaHeight / 2,
      ),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(offset: Offset(3, 3), blurRadius: 6, color: Colors.black),
            Shadow(offset: Offset(0, 0), blurRadius: 10, color: Colors.white),
          ],
        ),
      ),
    );
    add(statusText);

    // Create game over overlay components (initially hidden)
    // Full screen overlay with semi-transparent black background
    gameOverOverlay = RectangleComponent(
      position: Vector2(gameAreaX, gameAreaY),
      size: Vector2(gameAreaWidth, gameAreaHeight),
      paint: Paint()..color = Colors.black.withOpacity(0.8),
      priority: 10000, // Very high priority to ensure it renders on top
    );

    // Game over card - centered in the game area
    final cardWidth = 280.0;
    final cardHeight = 180.0;
    final cardX = gameAreaX + (gameAreaWidth - cardWidth) / 2;
    final cardY = gameAreaY + (gameAreaHeight - cardHeight) / 2;

    gameOverCard = RectangleComponent(
      position: Vector2(cardX, cardY),
      size: Vector2(cardWidth, cardHeight),
      paint: Paint()..color = const Color(0xFF1a1a1a),
      priority: 10001, // Higher priority than overlay
    );

    // Add border to the card
    gameOverCardBorder = RectangleComponent(
      position: Vector2(cardX - 2, cardY - 2),
      size: Vector2(cardWidth + 4, cardHeight + 4),
      paint:
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
      priority: 10001, // Same priority as card
    );

    // Game over text - centered in the card
    gameOverText = TextComponent(
      text: '',
      position: Vector2(cardX + cardWidth / 2, cardY + cardHeight / 2),
      anchor: Anchor.center,
      priority: 10002, // Highest priority for text
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.4,
          shadows: [
            Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black),
          ],
        ),
      ),
    );

    // Add overlay components but keep them hidden initially
    add(gameOverOverlay);
    add(gameOverCardBorder);
    add(gameOverCard);
    add(gameOverText);
    hideGameOverOverlay();
  }

  void showGameOverOverlay(String message) {
    gameOverOverlay.opacity = 1.0;
    gameOverCardBorder.opacity = 1.0;
    gameOverCard.opacity = 1.0;
    gameOverText.text = message;
    gameOverText.textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.3,
        shadows: [
          Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black),
        ],
      ),
    );
  }

  void hideGameOverOverlay() {
    gameOverOverlay.opacity = 0.0;
    gameOverCardBorder.opacity = 0.0;
    gameOverCard.opacity = 0.0;
    gameOverText.text = '';
  }

  void startGame() {
    if (isGameOver) {
      // Reset game
      board = List.generate(rows, (_) => List.filled(cols, false));
      boardColors = List.generate(rows, (_) => List.filled(cols, null));
      score = 0;
      level = 1;
      linesCleared = 0;
      isGameOver = false;
      hideGameOverOverlay();
      updateUI();
    }

    isGameStarted = true;
    isGamePaused = false;
    statusText.text = '';
    hideGameOverOverlay();

    // Initialize next piece
    nextPiece = Tetromino.createRandomPiece(cols ~/ 2);
    spawnPiece();
    _startTimer();
  }

  void pauseGame() {
    if (!isGameStarted || isGameOver) return;

    isGamePaused = !isGamePaused;

    if (isGamePaused) {
      gameTimer?.cancel();
      statusText.text = 'PAUSED\nTap to Resume';
    } else {
      statusText.text = '';
      _startTimer();
    }
  }

  void _startTimer() {
    gameTimer?.cancel();
    int dropSpeed = 600 - (level * 50); // Speed increases with level
    dropSpeed = dropSpeed.clamp(100, 600); // Minimum 100ms, maximum 600ms

    gameTimer = async.Timer.periodic(Duration(milliseconds: dropSpeed), (_) {
      if (!isGamePaused && isGameStarted && !isGameOver) {
        drop();
      }
    });
  }

  void gameOverCheck() {
    // Check if any block is at the top
    for (int x = 0; x < cols; x++) {
      if (board[0][x]) {
        isGameOver = true;
        isGameStarted = false;
        gameTimer?.cancel();
        statusText.text = '';

        // Show game over overlay on top of everything
        showGameOverOverlay('GAME OVER\n\nScore: $score\n\nTap to Restart');

        // Strong haptic feedback for game over
        HapticFeedback.heavyImpact();
        // Add a second impact after a short delay
        async.Timer(const Duration(milliseconds: 200), () {
          HapticFeedback.heavyImpact();
        });

        break;
      }
    }
  }

  void spawnPiece() {
    // Use the next piece as the current piece
    if (nextPiece != null) {
      piece = nextPiece;
      // Reset the position to spawn at top center
      piece!.blocks =
          piece!.blocks
              .map(
                (block) =>
                    Vector2(block.x - piece!.xOffset + cols ~/ 2, block.y),
              )
              .toList();
      piece!.xOffset = cols ~/ 2;
      add(piece!);
    } else {
      // Fallback if nextPiece is null
      piece = Tetromino.createRandomPiece(cols ~/ 2);
      add(piece!);
    }

    // Generate new next piece
    nextPiece = Tetromino.createRandomPiece(cols ~/ 2);
  }

  void drop() {
    if (piece == null) return;
    if (!piece!.move(0, 1, board)) {
      // Piece has landed - add subtle haptic feedback
      HapticFeedback.selectionClick();

      for (var b in piece!.blocks) {
        int x = b.x.toInt();
        int y = b.y.toInt();
        if (y >= 0 && y < rows && x >= 0 && x < cols) {
          board[y][x] = true;
          boardColors[y][x] = piece!.color; // Store the piece color
        }
      }
      remove(piece!);
      piece = null;
      clearLines();
      gameOverCheck();
      if (!isGameOver) {
        spawnPiece();
      }
    }
  }

  void clearLines() {
    int clearedCount = 0;
    List<int> linesToClear = [];

    // Find lines to clear
    for (int y = rows - 1; y >= 0; y--) {
      if (board[y].every((filled) => filled)) {
        linesToClear.add(y);
      }
    }
    if (linesToClear.isNotEmpty) {
      // Add haptic feedback based on number of lines cleared
      switch (linesToClear.length) {
        case 1:
          HapticFeedback.lightImpact();
          break;
        case 2:
          HapticFeedback.mediumImpact();
          break;
        case 3:
          HapticFeedback.heavyImpact();
          break;
        case 4: // Tetris!
          HapticFeedback.heavyImpact();
          // Double haptic for tetris
          async.Timer(const Duration(milliseconds: 100), () {
            HapticFeedback.heavyImpact();
          });
          break;
      }

      // Immediately clear lines without animation
      for (int y in linesToClear) {
        board.removeAt(y);
        boardColors.removeAt(y);
        board.insert(0, List.filled(cols, false));
        boardColors.insert(0, List.filled(cols, null));
        clearedCount++;
      }

      // Calculate score
      int points;
      switch (clearedCount) {
        case 1:
          points = 100;
          break;
        case 2:
          points = 300;
          break;
        case 3:
          points = 500;
          break;
        case 4:
          points = 800;
          break;
        default:
          points = 0;
      }

      score += points * level;
      linesCleared += clearedCount;

      int newLevel = (linesCleared ~/ 10) + 1;
      if (newLevel > level) {
        level = newLevel;
        _startTimer();
      }

      updateUI();
    }
  }

  void updateUI() {
    scoreText.textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        height: 1.2,
        shadows: [
          Shadow(color: Colors.white, blurRadius: 5, offset: Offset(0, 0)),
        ],
      ),
    );
    scoreText.text = 'SCORE\n$score';

    levelText.textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        height: 1.2,
        shadows: [
          Shadow(color: Colors.white, blurRadius: 5, offset: Offset(0, 0)),
        ],
      ),
    );
    levelText.text = 'LEVEL\n$level';

    linesText.textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        height: 1.2,
        shadows: [
          Shadow(color: Colors.white, blurRadius: 5, offset: Offset(0, 0)),
        ],
      ),
    );
    linesText.text = 'LINES\n$linesCleared';
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final gameAreaX = sidePadding * 1.5;
    final gameAreaY = 60;

    // Static border without animation
    gameAreaBorder.paint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;

    // Render board blocks without bounce animations
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final blockX = gameAreaX + x * blockSize;
        final blockY = gameAreaY + y * blockSize;

        if (board[y][x]) {
          // All blocks are white with gradient
          final blockPaint = Paint();
          blockPaint.shader = LinearGradient(
            colors: [Colors.white, Colors.grey[200]!, Colors.white],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromLTWH(blockX, blockY, blockSize, blockSize));

          final borderPaint =
              Paint()
                ..color = Colors.black
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0;

          // Add shadow
          final shadowPaint =
              Paint()
                ..color = Colors.black.withOpacity(0.3)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

          // Draw shadow
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(blockX + 2, blockY + 2, blockSize, blockSize),
              const Radius.circular(2),
            ),
            shadowPaint,
          );

          // Draw block with gradient
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(blockX, blockY, blockSize, blockSize),
              const Radius.circular(2),
            ),
            blockPaint,
          );

          // Draw border
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(blockX, blockY, blockSize, blockSize),
              const Radius.circular(2),
            ),
            borderPaint,
          );
        } else {
          // Draw subtle static grid lines
          final gridPaint =
              Paint()
                ..color = Colors.grey.withOpacity(0.05)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.5;

          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(blockX, blockY, blockSize, blockSize),
              const Radius.circular(1),
            ),
            gridPaint,
          );
        }
      }
    }

    // Render next piece preview
    renderNextPiecePreview(canvas);
  }

  void renderNextPiecePreview(Canvas canvas) {
    if (nextPiece == null) return;

    final gameAreaX = sidePadding * 1.5;
    final nextAreaX =
        gameAreaX + cols * blockSize + 10; // Updated to match UI positioning
    final nextAreaY = 260.0; // Updated to match UI positioning
    final nextAreaSize = 120.0;

    // Calculate preview position (centered in preview area)
    final previewCenterX = nextAreaX + nextAreaSize / 2;
    final previewCenterY = nextAreaY + nextAreaSize / 2;
    final previewBlockSize = 20.0; // Smaller blocks for preview

    // Create a smaller version of the next piece for preview
    final previewPaint = Paint();
    previewPaint.shader = LinearGradient(
      colors: [Colors.white, Colors.grey[300]!, Colors.white],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, previewBlockSize, previewBlockSize));

    final borderPaint =
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    final shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    // Find the bounds of the piece to center it
    double minX = nextPiece!.blocks.first.x;
    double maxX = nextPiece!.blocks.first.x;
    double minY = nextPiece!.blocks.first.y;
    double maxY = nextPiece!.blocks.first.y;

    for (final block in nextPiece!.blocks) {
      minX = minX < block.x ? minX : block.x;
      maxX = maxX > block.x ? maxX : block.x;
      minY = minY < block.y ? minY : block.y;
      maxY = maxY > block.y ? maxY : block.y;
    }

    final pieceWidth = (maxX - minX + 1) * previewBlockSize;
    final pieceHeight = (maxY - minY + 1) * previewBlockSize;
    final offsetX = previewCenterX - pieceWidth / 2 - minX * previewBlockSize;
    final offsetY = previewCenterY - pieceHeight / 2 - minY * previewBlockSize;

    // Render each block of the next piece
    for (final block in nextPiece!.blocks) {
      final blockX = offsetX + block.x * previewBlockSize;
      final blockY = offsetY + block.y * previewBlockSize;

      // Draw shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            blockX + 1,
            blockY + 1,
            previewBlockSize,
            previewBlockSize,
          ),
          const Radius.circular(1),
        ),
        shadowPaint,
      );

      // Draw block
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(blockX, blockY, previewBlockSize, previewBlockSize),
          const Radius.circular(1),
        ),
        previewPaint,
      );

      // Draw border
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(blockX, blockY, previewBlockSize, previewBlockSize),
          const Radius.circular(1),
        ),
        borderPaint,
      );
    }
  }

  @override
  void onRemove() {
    gameTimer?.cancel();
    super.onRemove();
  }

  // Gesture handling methods
  void handleTap() {
    if (!isGameStarted || isGameOver) {
      HapticFeedback.mediumImpact();
      startGame();
    } else if (isGamePaused) {
      HapticFeedback.lightImpact();
      pauseGame(); // Resume
    } else {
      HapticFeedback.selectionClick();
      piece?.rotate(board);
    }
  }

  void handleLongPress() {
    if (isGameStarted && !isGameOver) {
      HapticFeedback.mediumImpact();
      pauseGame();
    }
  }

  void handleSwipeLeft() {
    if (isGameStarted && !isGamePaused && !isGameOver) {
      HapticFeedback.selectionClick();
      piece?.move(-1, 0, board);
    }
  }

  void handleSwipeRight() {
    if (isGameStarted && !isGamePaused && !isGameOver) {
      HapticFeedback.selectionClick();
      piece?.move(1, 0, board);
    }
  }

  void handleSwipeDown() {
    if (isGameStarted && !isGamePaused && !isGameOver) {
      HapticFeedback.heavyImpact();
      // Drop piece instantly
      while (piece?.move(0, 1, board) == true) {
        // Keep dropping until it can't move down
      }
    }
  }

  void handleSwipeUp() {
    if (isGameStarted && !isGamePaused && !isGameOver) {
      HapticFeedback.selectionClick();
      piece?.rotate(board);
    }
  }
}

class Tetromino extends PositionComponent {
  List<Vector2> blocks;
  int xOffset;
  Color color;
  int pieceType;

  Tetromino({
    required this.blocks,
    this.xOffset = 0,
    required this.color,
    required this.pieceType,
  }) {
    position = Vector2.zero();
  }

  // All white color scheme
  static const List<Color> pieceColors = [
    Colors.white, // I-piece - White
    Colors.white, // O-piece - White
    Colors.white, // T-piece - White
    Colors.white, // S-piece - White
    Colors.white, // Z-piece - White
    Colors.white, // L-piece - White
    Colors.white, // J-piece - White
  ];

  static Tetromino createRandomPiece(int xOffset) {
    List<List<Vector2>> shapes = [
      [Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(2, 0)], // I-piece
      [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)], // O-piece
      [Vector2(0, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(1, 0)], // T-piece
      [Vector2(0, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(1, 1)], // S-piece
      [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 1)], // Z-piece
      [Vector2(0, 0), Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1)], // L-piece
      [Vector2(0, 0), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1)], // J-piece
    ];

    int pieceType = Random().nextInt(shapes.length);
    List<Vector2> blocks =
        shapes[pieceType]
            .map((v) => v + Vector2(xOffset.toDouble(), 0))
            .toList();

    return Tetromino(
      blocks: blocks,
      xOffset: xOffset,
      color: pieceColors[pieceType],
      pieceType: pieceType,
    );
  }

  static List<Vector2> randomShape(int xOffset) {
    // This method is deprecated, use createRandomPiece instead
    return createRandomPiece(xOffset).blocks;
  }

  bool move(int dx, int dy, List<List<bool>> board) {
    final moved =
        blocks.map((b) => b + Vector2(dx.toDouble(), dy.toDouble())).toList();
    if (moved.any(
      (b) =>
          b.x < 0 ||
          b.x >= RetroTetrisGame.cols ||
          b.y >= RetroTetrisGame.rows ||
          (b.y >= 0 && board[b.y.toInt()][b.x.toInt()]),
    )) {
      return false;
    }
    blocks = moved;
    return true;
  }

  void rotate(List<List<bool>> board) {
    final center = blocks[0];
    final rotated =
        blocks.map((b) {
          final dx = b.x - center.x;
          final dy = b.y - center.y;
          return Vector2(center.x - dy, center.y + dx);
        }).toList();
    if (rotated.any(
      (b) =>
          b.x < 0 ||
          b.x >= RetroTetrisGame.cols ||
          b.y >= RetroTetrisGame.rows ||
          (b.y >= 0 && board[b.y.toInt()][b.x.toInt()]),
    )) {
      return;
    }
    blocks = rotated;
  }

  @override
  void render(Canvas canvas) {
    // All pieces are white with consistent gradient
    final paint = Paint();
    paint.shader = LinearGradient(
      colors: [Colors.white, Colors.grey[300]!, Colors.white],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(
      Rect.fromLTWH(0, 0, RetroTetrisGame.blockSize, RetroTetrisGame.blockSize),
    );

    final borderPaint =
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    // Add subtle shadow
    final shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    for (final b in blocks) {
      if (b.y < 0) continue;
      final blockX =
          RetroTetrisGame.sidePadding * 1.5 + b.x * RetroTetrisGame.blockSize;
      final blockY = 60 + b.y * RetroTetrisGame.blockSize;

      const blockSize = RetroTetrisGame.blockSize;

      // Draw shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(blockX + 2, blockY + 2, blockSize, blockSize),
          const Radius.circular(2),
        ),
        shadowPaint,
      );

      // Draw filled block with gradient
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(blockX, blockY, blockSize, blockSize),
          const Radius.circular(2),
        ),
        paint,
      );

      // Draw border
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(blockX, blockY, blockSize, blockSize),
          const Radius.circular(2),
        ),
        borderPaint,
      );
    }
  }
}
