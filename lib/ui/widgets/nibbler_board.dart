import 'package:flutter/material.dart';
import '../../models/chess_move.dart';
import '../../models/chess_position.dart';
import '../../models/engine_analysis.dart';
import '../../services/theme_service.dart';
import 'nibbler_arrow_painter.dart';
import 'piece_widget.dart';

class NibblerBoard extends StatefulWidget {
  final ChessPosition position;
  final ChessMove? lastMove;
  final bool isFlipped;
  final BoardThemeData boardTheme;
  final String pieceSet;
  final List<PvLine> candidateLines;
  final List<CandidateArrow> candidateArrows;
  final ArrowheadType arrowheadType;
  final EngineType engineType;
  final int positionRevision;
  final int? analysisRequestId;
  final void Function(ChessMove move) onMove;
  final int animationDurationMs;

  const NibblerBoard({
    super.key,
    required this.position,
    this.positionRevision = 0,
    this.analysisRequestId,
    this.lastMove,
    this.isFlipped = false,
    required this.boardTheme,
    required this.pieceSet,
    this.candidateLines = const [],
    this.candidateArrows = const [],
    this.arrowheadType = ArrowheadType.winrate,
    this.engineType = EngineType.lc0,
    required this.onMove,
    this.animationDurationMs = 200,
  });

  @override
  State<NibblerBoard> createState() => _NibblerBoardState();
}

class _NibblerBoardState extends State<NibblerBoard>
    with SingleTickerProviderStateMixin {
  Square? _selectedSquare;
  List<ChessMove> _legalMovesForSelected = [];

  // Piece animation controller
  late AnimationController _animController;
  late Animation<double> _animCurve;
  ChessMove? _animatedMove;
  ChessPiece? _animatedCapturedPiece;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animationDurationMs),
    );
    _animCurve = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    if (widget.lastMove != null && widget.animationDurationMs > 0) {
      _animatedMove = widget.lastMove;
      _animatedCapturedPiece = widget.lastMove?.capturedPiece;
      _animController.forward(from: 0.0);
    } else {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(NibblerBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastMove != null &&
        widget.lastMove != oldWidget.lastMove &&
        widget.animationDurationMs > 0) {
      _animatedMove = widget.lastMove;
      _animatedCapturedPiece = widget.lastMove?.capturedPiece;
      _animController.duration = Duration(milliseconds: widget.animationDurationMs);
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onSquareTapped(Square square) {
    final pieceAtTarget = widget.position.pieceAt(square);

    if (_selectedSquare == square) {
      setState(() {
        _selectedSquare = null;
        _legalMovesForSelected = [];
      });
      return;
    }

    if (_selectedSquare != null) {
      final matchingMoves = _legalMovesForSelected.where((m) => m.to == square).toList();
      if (matchingMoves.isNotEmpty) {
        if (matchingMoves.length == 1 && matchingMoves.first.promotion == null) {
          _executeMove(matchingMoves.first);
          return;
        } else {
          _showPromotionDialog(matchingMoves);
          return;
        }
      }
    }

    if (pieceAtTarget != null && pieceAtTarget.color == widget.position.turn) {
      final legal = widget.position
          .generateLegalMoves()
          .where((m) => m.from == square)
          .toList();

      setState(() {
        _selectedSquare = square;
        _legalMovesForSelected = legal;
      });
    } else {
      setState(() {
        _selectedSquare = null;
        _legalMovesForSelected = [];
      });
    }
  }

  void _executeMove(ChessMove move) {
    setState(() {
      _selectedSquare = null;
      _legalMovesForSelected = [];
    });
    widget.onMove(move);
  }

  void _showPromotionDialog(List<ChessMove> promotionMoves) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final color = widget.position.turn;
        const options = [
          PieceType.queen,
          PieceType.rook,
          PieceType.bishop,
          PieceType.knight,
        ];

        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Promote Pawn',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: options.map((pt) {
              final move = promotionMoves.firstWhere(
                (m) => m.promotion == pt,
                orElse: () => promotionMoves.first,
              );
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _executeMove(move);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: PieceWidget(
                      piece: ChessPiece(pt, color),
                      size: 46,
                      pieceSet: widget.pieceSet,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.maxWidth;
        final squareSize = boardSize / 8.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: Stack(
              children: [
                // 1. Board background (Texture or Solid Color)
                _buildBoardBackground(boardSize, squareSize),

                // 2. Square highlights (Last Move, Selected, King Check)
                _buildHighlightsLayer(squareSize),

                // 3. Move target indicators (Legal Move Dots & Capture Rings)
                _buildMoveTargetsLayer(squareSize),

                // 4. Smooth animated chess pieces layer with Drag-and-Drop & Tap
                AnimatedBuilder(
                  animation: _animCurve,
                  builder: (context, child) {
                    return _buildPiecesLayer(squareSize);
                  },
                ),

                // 5. Multi-PV candidate move arrows with ChessCrack score badges (Isolated RepaintBoundary)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size(boardSize, boardSize),
                        painter: NibblerArrowPainter(
                          candidateArrows: widget.candidateArrows,
                          pvLines: widget.candidateLines,
                          position: widget.position,
                          positionRevision: widget.positionRevision,
                          analysisRequestId: widget.analysisRequestId,
                          isFlipped: widget.isFlipped,
                          arrowheadType: widget.arrowheadType,
                          engineType: widget.engineType,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardBackground(double boardSize, double squareSize) {
    return Stack(
      children: [
        // Background texture or solid squares
        if (widget.boardTheme.isTexture)
          Positioned.fill(
            child: Image.asset(
              widget.boardTheme.imageAssetPath!,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          )
        else
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 64,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
            itemBuilder: (context, index) {
              final row = index ~/ 8;
              final col = index % 8;
              final rank = widget.isFlipped ? row : (7 - row);
              final file = widget.isFlipped ? (7 - col) : col;
              final isLight = (file + rank) % 2 != 0;
              return Container(
                color: isLight ? widget.boardTheme.lightSquare : widget.boardTheme.darkSquare,
              );
            },
          ),

        // Interactive coordinate overlay & touch target grid
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 64,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
          itemBuilder: (context, index) {
            final row = index ~/ 8;
            final col = index % 8;
            final rank = widget.isFlipped ? row : (7 - row);
            final file = widget.isFlipped ? (7 - col) : col;
            final square = Square(file, rank);
            final isLight = square.isLight;

            final showRank = col == 0;
            final showFile = row == 7;

            // Contrasting coordinate text color according to Lichess rules
            final coordColor = isLight ? widget.boardTheme.darkSquare : widget.boardTheme.lightSquare;

            return DragTarget<Square>(
              onWillAcceptWithDetails: (details) {
                final fromSquare = details.data;
                return widget.position
                    .generateLegalMoves()
                    .any((m) => m.from == fromSquare && m.to == square);
              },
              onAcceptWithDetails: (details) {
                final fromSquare = details.data;
                final matching = widget.position
                    .generateLegalMoves()
                    .where((m) => m.from == fromSquare && m.to == square)
                    .toList();
                if (matching.isNotEmpty) {
                  if (matching.length == 1 && matching.first.promotion == null) {
                    _executeMove(matching.first);
                  } else {
                    _showPromotionDialog(matching);
                  }
                }
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onSquareTapped(square),
                  child: Container(
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        if (showRank)
                          Positioned(
                            top: 2,
                            left: 3,
                            child: Text(
                              '${rank + 1}',
                              style: TextStyle(
                                color: coordColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (showFile)
                          Positioned(
                            bottom: 2,
                            right: 3,
                            child: Text(
                              String.fromCharCode('a'.codeUnitAt(0) + file),
                              style: TextStyle(
                                color: coordColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
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
    );
  }

  Widget _buildHighlightsLayer(double squareSize) {
    final highlights = <Widget>[];

    // 1. Last Move Highlights
    if (widget.lastMove != null) {
      for (final sq in [widget.lastMove!.from, widget.lastMove!.to]) {
        final rect = _getSquareRect(sq, squareSize);
        highlights.add(Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            child: Container(color: widget.boardTheme.lastMoveHighlight),
          ),
        ));
      }
    }

    // 2. King Check Highlight
    if (widget.position.isCheck()) {
      final kingSq = widget.position.findKing(widget.position.turn);
      if (kingSq != null) {
        final rect = _getSquareRect(kingSq, squareSize);
        highlights.add(Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.red.withValues(alpha: 0.85), Colors.transparent],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
        ));
      }
    }

    // 3. Selected Square Highlight
    if (_selectedSquare != null) {
      final rect = _getSquareRect(_selectedSquare!, squareSize);
      highlights.add(Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: Container(color: widget.boardTheme.selectedHighlight),
        ),
      ));
    }

    return Stack(children: highlights);
  }

  Widget _buildMoveTargetsLayer(double squareSize) {
    final indicators = <Widget>[];

    // Lichess standard destination markers (dots on empty squares, concentric rings on captures)
    for (final move in _legalMovesForSelected) {
      final rect = _getSquareRect(move.to, squareSize);
      final isCapture = move.isCapture;

      indicators.add(Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: Center(
            child: isCapture
                ? Container(
                    width: squareSize * 0.86,
                    height: squareSize * 0.86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.boardTheme.validMovesColor,
                        width: squareSize * 0.08,
                      ),
                    ),
                  )
                : Container(
                    width: squareSize * 0.30,
                    height: squareSize * 0.30,
                    decoration: BoxDecoration(
                      color: widget.boardTheme.validMovesColor,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        ),
      ));
    }

    return Stack(children: indicators);
  }

  Widget _buildPiecesLayer(double squareSize) {
    final pieceWidgets = <Widget>[];
    final isAnimating = _animController.isAnimating;
    final animVal = _animCurve.value;

    Square? movingPieceDest;
    Square? movingPieceOrigin;
    ChessPiece? movingPiece;

    // Castling rook movement parameters
    Square? castlingRookDest;
    Square? castlingRookOrigin;
    ChessPiece? castlingRook;

    if (isAnimating && _animatedMove != null) {
      movingPieceDest = _animatedMove!.to;
      movingPieceOrigin = _animatedMove!.from;
      movingPiece = widget.position.pieceAt(movingPieceDest);

      if (_animatedMove!.isCastling) {
        if (_animatedMove!.piece.color.isWhite) {
          if (movingPieceDest == const Square(6, 0)) {
            castlingRookOrigin = const Square(7, 0);
            castlingRookDest = const Square(5, 0);
            castlingRook = const ChessPiece(PieceType.rook, PieceColor.white);
          } else if (movingPieceDest == const Square(2, 0)) {
            castlingRookOrigin = const Square(0, 0);
            castlingRookDest = const Square(3, 0);
            castlingRook = const ChessPiece(PieceType.rook, PieceColor.white);
          }
        } else {
          if (movingPieceDest == const Square(6, 7)) {
            castlingRookOrigin = const Square(7, 7);
            castlingRookDest = const Square(5, 7);
            castlingRook = const ChessPiece(PieceType.rook, PieceColor.black);
          } else if (movingPieceDest == const Square(2, 7)) {
            castlingRookOrigin = const Square(0, 7);
            castlingRookDest = const Square(3, 7);
            castlingRook = const ChessPiece(PieceType.rook, PieceColor.black);
          }
        }
      }
    }

    // 1. Static Pieces with Drag & Tap support
    for (int i = 0; i < 64; i++) {
      final piece = widget.position.board[i];
      if (piece == null) continue;

      final square = Square.fromIndex(i);

      // Skip the piece currently animating
      if (isAnimating && (square == movingPieceDest || square == castlingRookDest)) {
        continue;
      }

      final rect = _getSquareRect(square, squareSize);
      final isPieceDraggable = piece.color == widget.position.turn;

      Widget pieceItem = Center(
        child: PieceWidget(
          piece: piece,
          size: squareSize,
          pieceSet: widget.pieceSet,
        ),
      );

      if (isPieceDraggable) {
        pieceItem = Draggable<Square>(
          data: square,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.15,
              child: PieceWidget(
                piece: piece,
                size: squareSize,
                pieceSet: widget.pieceSet,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: PieceWidget(
              piece: piece,
              size: squareSize,
              pieceSet: widget.pieceSet,
            ),
          ),
          onDragStarted: () {
            final legal = widget.position
                .generateLegalMoves()
                .where((m) => m.from == square)
                .toList();
            setState(() {
              _selectedSquare = square;
              _legalMovesForSelected = legal;
            });
          },
          child: pieceItem,
        );
      }

      pieceWidgets.add(Positioned.fromRect(
        rect: rect,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onSquareTapped(square),
          child: pieceItem,
        ),
      ));
    }

    // 2. Captured Piece Fading Out & Shrinking
    if (isAnimating && _animatedCapturedPiece != null && movingPieceDest != null) {
      final capRect = _getSquareRect(movingPieceDest, squareSize);
      pieceWidgets.add(Positioned.fromRect(
        rect: capRect,
        child: IgnorePointer(
          child: Center(
            child: Transform.scale(
              scale: (1.0 - (animVal * 0.4)).clamp(0.0, 1.0),
              child: Opacity(
                opacity: (1.0 - animVal).clamp(0.0, 1.0),
                child: PieceWidget(
                  piece: _animatedCapturedPiece!,
                  size: squareSize,
                  pieceSet: widget.pieceSet,
                ),
              ),
            ),
          ),
        ),
      ));
    }

    // 3. Smooth Moving Piece (Interpolated Rect)
    if (isAnimating && movingPiece != null && movingPieceOrigin != null && movingPieceDest != null) {
      final fromRect = _getSquareRect(movingPieceOrigin, squareSize);
      final toRect = _getSquareRect(movingPieceDest, squareSize);
      final currentRect = Rect.lerp(fromRect, toRect, animVal)!;

      pieceWidgets.add(Positioned.fromRect(
        rect: currentRect,
        child: IgnorePointer(
          child: Center(
            child: Transform.scale(
              scale: 1.08,
              child: PieceWidget(
                piece: movingPiece,
                size: squareSize,
                pieceSet: widget.pieceSet,
              ),
            ),
          ),
        ),
      ));
    }

    // 4. Smooth Castling Rook (Interpolated Rect)
    if (isAnimating && castlingRook != null && castlingRookOrigin != null && castlingRookDest != null) {
      final rookFromRect = _getSquareRect(castlingRookOrigin, squareSize);
      final rookToRect = _getSquareRect(castlingRookDest, squareSize);
      final currentRookRect = Rect.lerp(rookFromRect, rookToRect, animVal)!;

      pieceWidgets.add(Positioned.fromRect(
        rect: currentRookRect,
        child: IgnorePointer(
          child: Center(
            child: PieceWidget(
              piece: castlingRook,
              size: squareSize,
              pieceSet: widget.pieceSet,
            ),
          ),
        ),
      ));
    }

    return Stack(children: pieceWidgets);
  }

  Rect _getSquareRect(Square sq, double squareSize) {
    final f = widget.isFlipped ? (7 - sq.file) : sq.file;
    final r = widget.isFlipped ? sq.rank : (7 - sq.rank);
    return Rect.fromLTWH(f * squareSize, r * squareSize, squareSize, squareSize);
  }
}
