import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:async' as async;
import 'dart:math';

void main() {
  runApp(MaterialApp(
    title: 'Tetris',
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0a0a0a),
    ),
    home: Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      body: SafeArea(
        child: Column(
          children: [
            // Title bar
            Container(
              height: 60,
              color: const Color(0xFF1a1a1a),
              child: const Center(
                child: Text(
                  'TETRIS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
            // Game area
            Expanded(
              child: TetrisGameWrapper(),
            ),
          ],
        ),
      ),
    ),
    debugShowCheckedModeBanner: false,
  ));
}

class TetrisGameWrapper extends StatefulWidget {
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
      onTap: () => game.handleTap(),
      onLongPress: () => game.handleLongPress(),
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        final speed = velocity.distance;

        if (speed < 300) return; // Ignore slow movements

        final dx = velocity.dx;
        final dy = velocity.dy;

        if (dx.abs() > dy.abs()) {
          // Horizontal swipe
          if (dx > 0) {
            game.handleSwipeRight();
          } else {
            game.handleSwipeLeft();
          }
        } else {
          // Vertical swipe
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
  static const double blockSize = 30; // Increased block size
  static const double borderWidth = 3.0; // Thicker border
  static const double sidePadding = 80.0; // More space for UI elements
  
  List<List<bool>> board = List.generate(rows, (_) => List.filled(cols, false));
  List<List<Color?>> boardColors = List.generate(rows, (_) => List.filled(cols, null)); // Store colors
  Tetromino? piece;
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

  @override
  Future<void> onLoad() async {
    final gameAreaWidth = cols * blockSize;
    final gameAreaHeight = rows * blockSize;
    
    // Make the game use more of the screen
    camera.viewfinder.visibleGameSize = Vector2(
      gameAreaWidth + sidePadding * 3, // More total width
      gameAreaHeight + 120, // More total height
    );
    
    // Center the game area
    final gameAreaX = sidePadding * 1.5;
    final gameAreaY = 60.0;
    
    // Create game area background
    gameArea = RectangleComponent(
      position: Vector2(gameAreaX, gameAreaY),
      size: Vector2(gameAreaWidth, gameAreaHeight),
      paint: Paint()..color = const Color(0xFF1a1a1a), // Dark background
    );
    add(gameArea);
    
    // Create game area border
    gameAreaBorder = RectangleComponent(
      position: Vector2(gameAreaX - borderWidth, gameAreaY - borderWidth),
      size: Vector2(gameAreaWidth + borderWidth * 2, gameAreaHeight + borderWidth * 2),
      paint: Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
    add(gameAreaBorder);
    
    // Score text (left side)
    scoreText = TextComponent(
      text: 'SCORE\n0',
      position: Vector2(20, 100),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18, // Larger font
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
    add(scoreText);
    
    // Level text (left side)
    levelText = TextComponent(
      text: 'LEVEL\n1',
      position: Vector2(20, 180),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18, // Larger font
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
    add(levelText);
    
    // Lines cleared text (left side)
    linesText = TextComponent(
      text: 'LINES\n0',
      position: Vector2(20, 260),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18, // Larger font
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
    add(linesText);
    
    // Instructions text (right side)
    instructionsText = TextComponent(
      text: 'CONTROLS:\n\nTap\nRotate\n\nLong Press\nPause\n\nSwipe Left/Right\nMove\n\nSwipe Down\nDrop',
      position: Vector2(gameAreaX + gameAreaWidth + 20, 100),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14, // Larger font
          height: 1.4,
        ),
      ),
    );
    add(instructionsText);
    
    // Status text (centered in game area)
    statusText = TextComponent(
      text: 'TAP TO START',
      position: Vector2(
        gameAreaX + gameAreaWidth / 2, 
        gameAreaY + gameAreaHeight / 2
      ),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24, // Larger font
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(3, 3),
              blurRadius: 6,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
    add(statusText);
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
      updateUI();
    }
    
    isGameStarted = true;
    isGamePaused = false;
    statusText.text = '';
    
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
        statusText.text = 'GAME OVER\nScore: $score\nTap to Restart';
        break;
      }
    }
  }

  void spawnPiece() {
    piece = Tetromino.createRandomPiece(cols ~/ 2);
    add(piece!);
  }

  void drop() {
    if (piece == null) return;
    if (!piece!.move(0, 1, board)) {
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
    
    for (int y = rows - 1; y >= 0; y--) {
      if (board[y].every((filled) => filled)) {
        board.removeAt(y);
        boardColors.removeAt(y); // Remove color row too
        board.insert(0, List.filled(cols, false));
        boardColors.insert(0, List.filled(cols, null)); // Insert empty color row
        clearedCount++;
        y++; // Check the same row again
      }
    }
    
    if (clearedCount > 0) {
      // Calculate score based on lines cleared
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
      
      // Level up every 10 lines
      int newLevel = (linesCleared ~/ 10) + 1;
      if (newLevel > level) {
        level = newLevel;
        _startTimer(); // Update timer speed
      }
      
      updateUI();
    }
  }

  void updateUI() {
    scoreText.text = 'SCORE\n$score';
    levelText.text = 'LEVEL\n$level';
    linesText.text = 'LINES\n$linesCleared';
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Render board blocks with their stored colors
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5; // Thicker borders
    
    final gameAreaX = sidePadding * 1.5;
    final gameAreaY = 60;
    
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final blockX = gameAreaX + x * blockSize;
        final blockY = gameAreaY + y * blockSize;
        
        if (board[y][x]) {
          // Draw filled block with stored color
          final blockPaint = Paint()..color = boardColors[y][x] ?? Colors.white;
          canvas.drawRect(
            Rect.fromLTWH(blockX, blockY, blockSize, blockSize),
            blockPaint,
          );
          // Draw block border
          canvas.drawRect(
            Rect.fromLTWH(blockX, blockY, blockSize, blockSize),
            borderPaint,
          );
        } else {
          // Draw subtle grid lines for empty spaces
          final gridPaint = Paint()
            ..color = Colors.grey.withOpacity(0.1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5;
          canvas.drawRect(
            Rect.fromLTWH(blockX, blockY, blockSize, blockSize),
            gridPaint,
          );
        }
      }
    }
  }

  // Gesture handling methods
  void handleTap() {
    if (!isGameStarted || isGameOver) {
      startGame();
    } else if (isGamePaused) {
      pauseGame(); // Resume
    } else {
      piece?.rotate(board);
    }
  }

  void handleLongPress() {
    if (isGameStarted && !isGameOver) {
      pauseGame();
    }
  }

  void handleSwipeLeft() {
    if (isGameStarted && !isGamePaused && !isGameOver) {
      piece?.move(-1, 0, board);
    }
  }

  void handleSwipeRight() {
    if (isGameStarted && !isGamePaused && !isGameOver) {
      piece?.move(1, 0, board);
    }
  }

  void handleSwipeDown() {
    if (isGameStarted && !isGamePaused && !isGameOver) {
      // Drop piece instantly
      while (piece?.move(0, 1, board) == true) {
        // Keep dropping until it can't move down
      }
    }
  }

  void handleSwipeUp() {
    if (isGameStarted && !isGamePaused && !isGameOver) {
      piece?.rotate(board);
    }
  }
}

class Tetromino extends PositionComponent {
  List<Vector2> blocks;
  int xOffset;
  Color color;
  int pieceType;

  Tetromino({required this.blocks, this.xOffset = 0, required this.color, required this.pieceType}) {
    position = Vector2.zero();
  }

  static const List<Color> pieceColors = [
    Color(0xFF00FFFF), // Cyan - I-piece
    Color(0xFFFFFF00), // Yellow - O-piece  
    Color(0xFF800080), // Purple - T-piece
    Color(0xFF00FF00), // Green - S-piece
    Color(0xFFFF0000), // Red - Z-piece
    Color(0xFFFF8000), // Orange - L-piece
    Color(0xFF0000FF), // Blue - J-piece
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
    List<Vector2> blocks = shapes[pieceType]
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
    final moved = blocks
        .map((b) => b + Vector2(dx.toDouble(), dy.toDouble()))
        .toList();
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
    final rotated = blocks.map((b) {
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
    final paint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    for (final b in blocks) {
      if (b.y < 0) continue;
      final blockX = RetroTetrisGame.sidePadding * 1.5 + b.x * RetroTetrisGame.blockSize;
      final blockY = 60 + b.y * RetroTetrisGame.blockSize;
      
      // Draw filled block with color
      canvas.drawRect(
        Rect.fromLTWH(
          blockX,
          blockY,
          RetroTetrisGame.blockSize,
          RetroTetrisGame.blockSize,
        ),
        paint,
      );
      
      // Draw white border
      canvas.drawRect(
        Rect.fromLTWH(
          blockX,
          blockY,
          RetroTetrisGame.blockSize,
          RetroTetrisGame.blockSize,
        ),
        borderPaint,
      );
    }
  }
}
