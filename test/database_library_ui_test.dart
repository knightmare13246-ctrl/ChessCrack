import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_database_models.dart';
import 'package:nibbler_chess/services/chesscrack_core.dart';
import 'package:nibbler_chess/services/pgn_parser.dart';
import 'package:nibbler_chess/ui/screens/database_library_screen.dart';
import 'package:nibbler_chess/ui/screens/database_stats_dialog.dart';
import 'package:nibbler_chess/ui/screens/game_list_screen.dart';

late ChessDatabase testDb;

void main() {
  setUpAll(() async {
    final tempDb = File('${Directory.systemTemp.path}/chesscrack_ui_test_${DateTime.now().millisecondsSinceEpoch}.db');
    if (tempDb.existsSync()) tempDb.deleteSync();
    await ChessCrackCore.instance.init(tempDb.path);

    // Seed a couple databases and games
    final dbs = await ChessCrackCore.instance.listDatabases();
    testDb = ChessDatabase.fromJson(dbs.first);
    await ChessCrackCore.instance.savePgn(
      dbId: testDb.id,
      pgn: PgnParser.sampleKasparovTopalov,
    );
  });

  tearDownAll(() {
    ChessCrackCore.instance.dispose();
  });

  const testViewports = [
    Size(360, 640),  // Small Android
    Size(390, 844),  // Modern phone
    Size(430, 932),  // Large phone
    Size(800, 480),  // Landscape phone
    Size(1024, 768), // Landscape tablet
    Size(768, 1024), // Portrait tablet
  ];

  for (final vp in testViewports) {
    testWidgets('DatabaseLibraryScreen renders with zero overflow on ${vp.width}x${vp.height}', (tester) async {
      await tester.binding.setSurfaceSize(vp);

      await tester.pumpWidget(
        const MaterialApp(
          home: DatabaseLibraryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Chess Library'), findsOneWidget);
      expect(find.text('My Games'), findsOneWidget);
    });

    testWidgets('GameListScreen renders with zero overflow on ${vp.width}x${vp.height}', (tester) async {
      await tester.binding.setSurfaceSize(vp);

      await tester.pumpWidget(
        MaterialApp(
          home: GameListScreen(database: testDb),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('My Games'), findsOneWidget);
      expect(find.textContaining('Kasparov'), findsWidgets);
    });

    testWidgets('DatabaseStatsDialog renders with zero overflow on ${vp.width}x${vp.height}', (tester) async {
      await tester.binding.setSurfaceSize(vp);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatabaseStatsDialog(database: testDb),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull);
      expect(find.text('Total Games'), findsOneWidget);
      expect(find.text('Integrity Check'), findsOneWidget);
    });
  }

  testWidgets('Create New Database dialog has zero overflow when soft keyboard is open in portrait', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(() {
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DatabaseLibraryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap New Database button
    final newDbBtn = find.text('New Database');
    expect(newDbBtn, findsOneWidget);
    await tester.tap(newDbBtn);
    await tester.pumpAndSettle();

    // Verify dialog opened without overflow
    expect(tester.takeException(), isNull);
    expect(find.text('Create New Database'), findsOneWidget);
    expect(find.text('Database Name'), findsOneWidget);
    expect(find.text('Card Color'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);

    // Cancel to close
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Create New Database dialog has zero overflow when soft keyboard is open in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 480));
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(() {
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DatabaseLibraryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final newDbBtn = find.text('New Database');
    expect(newDbBtn, findsOneWidget);
    await tester.tap(newDbBtn);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Create New Database'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Full Database CRUD: Create, Edit/Rename, Reference, Delete', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));

    await tester.pumpWidget(
      const MaterialApp(
        home: DatabaseLibraryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Create a new database named "Tactics Master"
    await tester.tap(find.text('New Database'));
    await tester.pumpAndSettle();
    expect(find.text('Create New Database'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Database Name'), 'Tactics Master');
    await tester.enterText(find.widgetWithText(TextField, 'Description (optional)'), 'Daily puzzle collection');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Tactics Master'), findsOneWidget);
    expect(find.text('Daily puzzle collection'), findsOneWidget);

    // 2. Open popup menu on "Tactics Master" and Edit/Rename
    final moreButtons = find.byIcon(Icons.more_vert);
    expect(moreButtons, findsWidgets);
    // Tap the more button for the newly created database (the last one)
    await tester.tap(moreButtons.last);
    await tester.pumpAndSettle();

    expect(find.text('Edit / Rename'), findsOneWidget);
    await tester.tap(find.text('Edit / Rename'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Database'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Database Name'), 'Tactics Pro');
    // Toggle reference database
    await tester.tap(find.text('Reference Database'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Tactics Pro'), findsOneWidget);
    expect(find.text('REF'), findsOneWidget);

    // 3. Delete "Tactics Pro"
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();

    expect(find.text('Delete Database'), findsOneWidget);
    await tester.tap(find.text('Delete Database'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Database?'), findsOneWidget);
    expect(find.textContaining('This is your active Reference Database'), findsOneWidget);

    // Confirm deletion
    final deleteConfirmBtn = find.widgetWithText(ElevatedButton, 'Delete Database');
    await tester.tap(deleteConfirmBtn);
    await tester.pump();

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 600));
    });
    await tester.pumpAndSettle();

    expect(find.text('Tactics Pro'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Protected default database cannot be deleted', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));

    await tester.pumpWidget(
      const MaterialApp(
        home: DatabaseLibraryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // The first database is "My Games" (protected default)
    final firstMoreBtn = find.byIcon(Icons.more_vert).first;
    await tester.tap(firstMoreBtn);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete Database'));
    await tester.pumpAndSettle();

    expect(find.text('Protected Database'), findsOneWidget);
    expect(find.textContaining('cannot be deleted'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('My Games'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GameListScreen database management options in AppBar work properly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));

    await tester.pumpWidget(
      MaterialApp(
        home: GameListScreen(database: testDb),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Verify more_vert in GameListScreen AppBar
    final moreBtn = find.byIcon(Icons.more_vert);
    expect(moreBtn, findsOneWidget);
    await tester.tap(moreBtn);
    await tester.pumpAndSettle();

    expect(find.text('Edit / Rename'), findsOneWidget);
    expect(find.text('Set as Reference'), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Delete Database'), findsOneWidget);

    // Open Edit / Rename
    await tester.tap(find.text('Edit / Rename'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Database'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
