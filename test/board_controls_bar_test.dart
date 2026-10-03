import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/ui/widgets/board_controls_bar.dart';

void main() {
  group('BoardControlsBar Widget Tests', () {
    testWidgets('renders all 6 control buttons (Start, Back, Play/Pause, Forward, End, Flip)', (tester) async {
      bool goToStartCalled = false;
      bool stepBackwardCalled = false;
      bool toggleAutoPlayCalled = false;
      bool stepForwardCalled = false;
      bool goToEndCalled = false;
      bool flipBoardCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardControlsBar(
              canStepBackward: true,
              canStepForward: true,
              isAutoPlaying: false,
              onGoToStart: () => goToStartCalled = true,
              onStepBackward: () => stepBackwardCalled = true,
              onToggleAutoPlay: () => toggleAutoPlayCalled = true,
              onStepForward: () => stepForwardCalled = true,
              onGoToEnd: () => goToEndCalled = true,
              onFlipBoard: () => flipBoardCalled = true,
            ),
          ),
        ),
      );

      // Verify icons rendered
      expect(find.byIcon(Icons.first_page), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.last_page), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);

      // Tap buttons and verify callbacks
      await tester.tap(find.byIcon(Icons.first_page));
      expect(goToStartCalled, isTrue);

      await tester.tap(find.byIcon(Icons.chevron_left));
      expect(stepBackwardCalled, isTrue);

      await tester.tap(find.byIcon(Icons.play_arrow));
      expect(toggleAutoPlayCalled, isTrue);

      await tester.tap(find.byIcon(Icons.chevron_right));
      expect(stepForwardCalled, isTrue);

      await tester.tap(find.byIcon(Icons.last_page));
      expect(goToEndCalled, isTrue);

      await tester.tap(find.byIcon(Icons.swap_vert));
      expect(flipBoardCalled, isTrue);
    });

    testWidgets('renders pause icon when isAutoPlaying is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BoardControlsBar(
              canStepBackward: true,
              canStepForward: true,
              isAutoPlaying: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('disables backward and forward when canStep is false', (tester) async {
      bool stepBackwardCalled = false;
      bool stepForwardCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardControlsBar(
              canStepBackward: false,
              canStepForward: false,
              isAutoPlaying: false,
              onStepBackward: () => stepBackwardCalled = true,
              onStepForward: () => stepForwardCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      expect(stepBackwardCalled, isFalse);

      await tester.tap(find.byIcon(Icons.chevron_right));
      expect(stepForwardCalled, isFalse);
    });
  });
}
