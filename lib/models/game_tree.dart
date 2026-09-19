import 'chess_move.dart';
import 'chess_position.dart';
import 'engine_analysis.dart';

class GameNode {
  final String id;
  final ChessPosition position;
  final ChessMove? move;
  GameNode? parent;
  final List<GameNode> children = [];
  String? comment;
  final List<int> nags = [];
  PositionAnalysis? cachedAnalysis;

  bool isOriginalMainline = false;

  GameNode({
    required this.id,
    required this.position,
    this.move,
    this.parent,
    this.comment,
    this.isOriginalMainline = false,
  });

  bool get isRoot => parent == null;
  bool get hasChildren => children.isNotEmpty;
  GameNode? get mainChild => children.isNotEmpty ? children.first : null;

  int get ply {
    int count = 0;
    GameNode? curr = this;
    while (curr?.parent != null) {
      count++;
      curr = curr?.parent;
    }
    return count;
  }

  int get moveNumber => (ply + 1) ~/ 2;
  bool get isWhiteMove => ply % 2 == 1;

  String get moveNotation {
    if (move == null) return '';
    final san = move!.san ?? move!.uci;
    if (isWhiteMove) {
      return '$moveNumber. $san';
    } else {
      return '$moveNumber... $san';
    }
  }

  void addChild(GameNode node) {
    node.parent = this;
    children.add(node);
  }
}

class GameTree {
  GameNode root;
  GameNode currentNode;
  Map<String, String> headers;
  int _nodeIdCounter = 0;

  GameTree({
    required this.root,
    Map<String, String>? headers,
  })  : currentNode = root,
        headers = headers ?? {} {
    root.isOriginalMainline = true;
  }

  factory GameTree.initial() {
    final rootNode = GameNode(
      id: '0',
      position: ChessPosition.initial(),
      isOriginalMainline: true,
    );
    return GameTree(root: rootNode);
  }

  String _generateId() => (++_nodeIdCounter).toString();

  bool canStepForward() => currentNode.hasChildren;
  bool canStepBackward() => !currentNode.isRoot;

  bool stepForward([int variationIndex = 0]) {
    if (currentNode.hasChildren) {
      final index = variationIndex.clamp(0, currentNode.children.length - 1);
      currentNode = currentNode.children[index];
      return true;
    }
    return false;
  }

  bool stepBackward() {
    if (currentNode.parent != null) {
      currentNode = currentNode.parent!;
      return true;
    }
    return false;
  }

  void goToStart() {
    currentNode = root;
  }

  void goToEndOfCurrentLine() {
    while (currentNode.hasChildren) {
      currentNode = currentNode.children.first;
    }
  }

  void jumpToNode(GameNode node) {
    currentNode = node;
  }

  bool returnToOriginalGame() {
    final originalNodes = <GameNode>[];
    GameNode? curr = root;
    while (curr != null) {
      if (curr.isOriginalMainline) {
        originalNodes.add(curr);
      }
      curr = curr.children.cast<GameNode?>().firstWhere(
            (c) => c!.isOriginalMainline,
            orElse: () => null,
          );
    }

    if (originalNodes.isEmpty) {
      currentNode = root;
      return true;
    }

    final currentPly = currentNode.ply;
    GameNode target = originalNodes.last;
    for (final node in originalNodes) {
      if (node.ply == currentPly) {
        target = node;
        break;
      }
    }

    currentNode = target;
    return true;
  }

  GameNode addMove(ChessMove move) {
    for (final child in currentNode.children) {
      if (child.move == move || child.move?.uci == move.uci) {
        currentNode = child;
        return child;
      }
    }

    final nextPosition = currentNode.position.applyMove(move);
    final newNode = GameNode(
      id: _generateId(),
      position: nextPosition,
      move: move,
      parent: currentNode,
      isOriginalMainline: false,
    );

    currentNode.addChild(newNode);
    currentNode = newNode;
    return newNode;
  }

  void promoteVariation(GameNode child) {
    final parent = child.parent;
    if (parent != null && parent.children.contains(child)) {
      parent.children.remove(child);
      parent.children.insert(0, child);
    }
  }

  void deleteVariation(GameNode child) {
    final parent = child.parent;
    if (parent != null) {
      parent.children.remove(child);
      if (currentNode == child) {
        currentNode = parent;
      }
    }
  }

  List<GameNode> get currentPath {
    final path = <GameNode>[];
    GameNode? curr = currentNode;
    while (curr != null) {
      path.insert(0, curr);
      curr = curr.parent;
    }
    return path;
  }

  List<GameNode> get mainlineNodes {
    final list = <GameNode>[];
    GameNode? curr = root;
    while (curr != null) {
      list.add(curr);
      curr = curr.children.isNotEmpty ? curr.children.first : null;
    }
    return list;
  }
}
