import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/ui/widgets/arrow_settings_dialog.dart';
import 'package:nibbler_chess/ui/widgets/nibbler_eval_bar.dart';

void main() {
  testWidgets('NibblerEvalBar renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NibblerEvalBar(
            whiteWinPercentage: 55.0,
            height: 300.0,
          ),
        ),
      ),
    );
    expect(find.byType(NibblerEvalBar), findsOneWidget);
  });

  testWidgets('ArrowSettingsDialog opens and renders correctly', (WidgetTester tester) async {
    final settings = EngineSettings(activeEngine: EngineType.lc0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => ArrowSettingsDialog.show(
                ctx,
                settings: settings,
                onSettingsChanged: (_) {},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Arrow & Telemetry Settings'), findsOneWidget);
    expect(find.text('ARROWHEAD TYPE (BADGE DISPLAY)'), findsOneWidget);
    expect(find.text('Winrate'), findsOneWidget);
    expect(find.text('Policy'), findsOneWidget);
    expect(find.text('Node %'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('ArrowSettingsDialog allows selecting Policy mode and updates settings', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final settings = EngineSettings(activeEngine: EngineType.lc0);
    EngineSettings? updatedResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => ArrowSettingsDialog.show(
                ctx,
                settings: settings,
                onSettingsChanged: (s) => updatedResult = s,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Policy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(updatedResult, isNotNull);
    expect(updatedResult!.arrowheadType, equals(ArrowheadType.policy));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
