import '../models/chess_position.dart';
import '../models/game_tree.dart';

class PgnParser {
  static GameTree parse(String pgnContent) {
    final headers = <String, String>{};
    final lines = pgnContent.split('\n');
    final moveLines = <String>[];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('[') && line.endsWith(']')) {
        final match = RegExp(r'^\[(\w+)\s+"(.*)"\]$').firstMatch(line);
        if (match != null) {
          headers[match.group(1)!] = match.group(2)!;
        }
      } else if (!line.startsWith('%')) {
        moveLines.add(line);
      }
    }

    final moveText = moveLines.join(' ');

    ChessPosition rootPosition = ChessPosition.initial();
    if (headers.containsKey('FEN')) {
      try {
        rootPosition = ChessPosition.fromFen(headers['FEN']!);
      } catch (_) {
        rootPosition = ChessPosition.initial();
      }
    }

    final rootNode = GameNode(
      id: '0',
      position: rootPosition,
      isOriginalMainline: true,
    );

    final tree = GameTree(root: rootNode, headers: headers);
    _parseMoveText(tree, rootNode, moveText);
    tree.goToStart();

    return tree;
  }

  static void _parseMoveText(GameTree tree, GameNode startNode, String moveText) {
    int pos = 0;
    final length = moveText.length;

    GameNode currentNode = startNode;
    final nodeStack = <GameNode>[];

    while (pos < length) {
      while (pos < length && moveText[pos].trim().isEmpty) {
        pos++;
      }
      if (pos >= length) break;

      final char = moveText[pos];

      if (char == '{') {
        final endBrace = moveText.indexOf('}', pos);
        if (endBrace != -1) {
          final comment = moveText.substring(pos + 1, endBrace).trim();
          currentNode.comment = comment;
          pos = endBrace + 1;
        } else {
          pos = length;
        }
        continue;
      }

      if (char == '(') {
        nodeStack.add(currentNode);
        if (currentNode.parent != null) {
          currentNode = currentNode.parent!;
        }
        pos++;
        continue;
      }

      if (char == ')') {
        if (nodeStack.isNotEmpty) {
          currentNode = nodeStack.removeLast();
        }
        pos++;
        continue;
      }

      int tokenEnd = pos;
      while (tokenEnd < length &&
          moveText[tokenEnd].trim().isNotEmpty &&
          moveText[tokenEnd] != '(' &&
          moveText[tokenEnd] != ')' &&
          moveText[tokenEnd] != '{') {
        tokenEnd++;
      }

      var token = moveText.substring(pos, tokenEnd).trim();
      pos = tokenEnd;

      if (token.isEmpty) continue;

      if (token == '1-0' || token == '0-1' || token == '1/2-1/2' || token == '*') {
        continue;
      }

      if (token.startsWith(r'$')) {
        final nag = int.tryParse(token.substring(1));
        if (nag != null) {
          currentNode.nags.add(nag);
        }
        continue;
      }

      if (RegExp(r'^\d+(\.+)?$').hasMatch(token)) {
        continue;
      }

      if (RegExp(r'^\d+\.+(.*)$').hasMatch(token)) {
        token = token.replaceFirst(RegExp(r'^\d+\.+'), '');
        if (token.isEmpty) continue;
      }

      final cleanSan = token.replaceAll(RegExp(r'[!?]+$'), '');

      final legalMove = currentNode.position.findLegalMoveBySan(cleanSan);
      if (legalMove != null) {
        final isMainline = nodeStack.isEmpty && currentNode.isOriginalMainline;
        final nextPos = currentNode.position.applyMove(legalMove);

        GameNode? nextNode;
        for (final child in currentNode.children) {
          if (child.move == legalMove || child.move?.uci == legalMove.uci) {
            nextNode = child;
            break;
          }
        }

        if (nextNode == null) {
          nextNode = GameNode(
            id: '${currentNode.id}_${currentNode.children.length}',
            position: nextPos,
            move: legalMove,
            parent: currentNode,
            isOriginalMainline: isMainline,
          );
          currentNode.addChild(nextNode);
        }

        currentNode = nextNode;
      }
    }
  }

  static String exportPgn(GameTree tree) {
    final buffer = StringBuffer();

    tree.headers.forEach((key, val) {
      buffer.writeln('[$key "$val"]');
    });
    if (tree.headers.isNotEmpty) buffer.writeln();

    _writeNodeMoves(buffer, tree.root);

    final result = tree.headers['Result'] ?? '*';
    buffer.write(' $result\n');

    return buffer.toString();
  }

  static void _writeNodeMoves(StringBuffer buffer, GameNode node) {
    if (!node.hasChildren) return;

    for (int i = 0; i < node.children.length; i++) {
      final child = node.children[i];
      final isVariation = i > 0;

      if (isVariation) {
        buffer.write(' (');
      }

      if (child.isWhiteMove) {
        buffer.write('${child.moveNumber}. ${child.move?.san ?? child.move?.uci} ');
      } else {
        if (isVariation || i == 0 && child.parent?.isRoot == true) {
          buffer.write('${child.moveNumber}... ${child.move?.san ?? child.move?.uci} ');
        } else {
          buffer.write('${child.move?.san ?? child.move?.uci} ');
        }
      }

      if (child.comment != null && child.comment!.isNotEmpty) {
        buffer.write('{${child.comment}} ');
      }

      _writeNodeMoves(buffer, child);

      if (isVariation) {
        buffer.write(')');
      }
    }
  }

  static const String sampleKasparovTopalov = '''
[Event "Hoogovens Group A"]
[Site "Wijk aan Zee NED"]
[Date "1999.01.20"]
[Round "4"]
[White "Kasparov, Garry"]
[Black "Topalov, Veselin"]
[Result "1-0"]
[WhiteElo "2812"]
[BlackElo "2700"]

1. e4 d6 2. d4 Nf6 3. Nc3 g6 4. Be3 Bg7 5. Qd2 c6 6. f3 b5 7. Nge2 Nbd7 8. Bh6
Bxh6 9. Qxh6 Bb7 10. a3 e5 11. O-O-O Qe7 12. Kb1 a6 13. Nc1 O-O-O 14. Nb3 exd4
15. Rxd4 c5 16. Rd1 Nb6 17. g3 Kb8 18. Na5 Ba8 19. Bh3 d5 20. Qf4+ Ka7 21. Rhe1
d4 22. Nd5 Nbxd5 23. exd5 Qd6 24. Rxd4 cxd4 25. Re7+ Kb6 26. Qxd4+ Kxa5 27. b4+
Ka4 28. Qc3 Qxd5 29. Ra7 Bb7 30. Rxb7 Qc4 31. Qxf6 Kxa3 32. Qxa6+ Kxb4 33. c3+
Kxc3 34. Qa1+ Kd2 35. Qb2+ Kd1 36. Bf1 Rd2 37. Rd7 Rxd7 38. Bxc4 bxc4 39. Qxh8
Rd3 40. Qa8 c3 41. Qa4+ Ke1 42. f4 f5 43. Kc1 Rd2 44. Qa7 1-0
''';

  static const String sampleFischerGameOfCentury = '''
[Event "Third Rosenwald Trophy"]
[Site "New York, NY USA"]
[Date "1956.10.17"]
[Round "8"]
[White "Donald Byrne"]
[Black "Robert James Fischer"]
[Result "0-1"]

1. Nf3 Nf6 2. c4 g6 3. Nc3 Bg7 4. d4 O-O 5. Bf4 d5 6. Qb3 dxc4 7. Qxc4 c6 8. e4
Nbd7 9. Rd1 Nb6 10. Qc5 Bg4 11. Bg5 Na4 12. Qa3 Nxc3 13. bxc3 Nxe4 14. Bxe7 Qb6
15. Bc4 Nxc3 16. Bc5 Rfe8+ 17. Kf1 Be6 18. Bxb6 Bxc4+ 19. Kg1 Ne2+ 20. Kf1 Nxd4+
21. Kg1 Ne2+ 22. Kf1 Nc3+ 23. Kg1 axb6 24. Qb4 Ra4 25. Qxb6 Nxd1 26. h3 Rxa2
27. Kh2 Nxf2 28. Re1 Rxe1 29. Qd8+ Bf8 30. Nxe1 Bd5 31. Nf3 Ne4 32. Qb8 b5
33. h4 h5 34. Ne5 Kg7 35. Kg1 Bc5+ 36. Kf1 Ng3+ 37. Ke1 Bb4+ 38. Kd1 Bb3+
39. Kc1 Ne2+ 40. Kb1 Nc3+ 41. Kc1 Rc2# 0-1
''';
}
