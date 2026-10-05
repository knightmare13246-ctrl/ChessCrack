import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/services/chesscrack_core.dart';
import 'package:nibbler_chess/services/pgn_parser.dart';

void main() {
  setUpAll(() async {
    final tempDb = File('${Directory.systemTemp.path}/chesscrack_test_${DateTime.now().millisecondsSinceEpoch}.db');
    if (tempDb.existsSync()) tempDb.deleteSync();
    await ChessCrackCore.instance.init(tempDb.path);
  });

  tearDownAll(() {
    ChessCrackCore.instance.dispose();
  });

  test('ChessCrackCore initializes and lists databases', () async {
    final dbs = await ChessCrackCore.instance.listDatabases();
    expect(dbs.isNotEmpty, isTrue);
    expect(dbs.first['name'], 'My Games');
  });

  test('Save, query, and reload game via ChessCrackCore', () async {
    final dbs = await ChessCrackCore.instance.listDatabases();
    final myGamesId = dbs.first['id'] as int;

    final saveRes = await ChessCrackCore.instance.savePgn(
      dbId: myGamesId,
      pgn: PgnParser.sampleKasparovTopalov,
    );

    final ids = (saveRes['ids'] as List).cast<int>();
    expect(ids.isNotEmpty, isTrue);
    final gameId = ids.first;

    final games = await ChessCrackCore.instance.searchGames(
      dbId: myGamesId,
      filter: {'player': 'Kasparov'},
    );
    expect(games.isNotEmpty, isTrue);
    expect(games.first['white'], 'Kasparov, Garry');

    final pgn = await ChessCrackCore.instance.getGamePgn(gameId);
    expect(pgn.contains('Kasparov'), isTrue);
    expect(pgn.contains('Bxh6'), isTrue);

    // Verify existing Dart GameTree can parse the PGN verbatim
    final tree = PgnParser.parse(pgn);
    expect(tree.headers['White'], 'Kasparov, Garry');
    expect(tree.root.children.isNotEmpty, isTrue);
  });

  test('Duplicate detection rejects duplicate game', () async {
    final dbs = await ChessCrackCore.instance.listDatabases();
    final myGamesId = dbs.first['id'] as int;

    final countBefore = await ChessCrackCore.instance.countGames(myGamesId);

    final res = await ChessCrackCore.instance.savePgn(
      dbId: myGamesId,
      pgn: PgnParser.sampleKasparovTopalov,
    );

    expect(res['duplicates'], 1);
    final countAfter = await ChessCrackCore.instance.countGames(myGamesId);
    expect(countAfter, countBefore);
  });

  test('Create, populate and delete database', () async {
    final newId = await ChessCrackCore.instance.createDatabase(
      name: 'Temp Test DB',
      category: 'testing',
      color: 0xFF2196F3,
      icon: 'folder',
      description: 'Temporary database for deletion testing',
    );
    expect(newId > 0, isTrue);

    // Save a game into it
    final saveRes = await ChessCrackCore.instance.savePgn(
      dbId: newId,
      pgn: PgnParser.sampleKasparovTopalov,
    );
    expect((saveRes['ids'] as List).isNotEmpty, isTrue);

    // Now delete it
    await ChessCrackCore.instance.deleteDatabase(newId);

    // Verify it is gone
    final dbs = await ChessCrackCore.instance.listDatabases();
    expect(dbs.any((d) => d['id'] == newId), isFalse);
  });
}
