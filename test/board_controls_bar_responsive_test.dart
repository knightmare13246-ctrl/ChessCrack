import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/ui/widgets/board_controls_bar.dart';

void main() {
  testWidgets('BoardControlsBar never overflows across screen widths from 280 to 1024 dp', (WidgetTester tester) async {
    final widths = [280.0, 320.0, 360.0, 400.0, 600.0, 1024.0];

    for (final width in widths) {
      await tester.binding.setSurfaceSize(Size(width, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: BoardControlsBar(
                canStepBackward: true,
                canStepForward: true,
                isAutoPlaying: false,
                isPlanActive: true,
                onGoToStart: () {},
                onStepBackward: () {},
                onToggleAutoPlay: () {},
                onStepForward: () {},
                onGoToEnd: () {},
                onFlipBoard: () {},
                onTogglePlan: () {},
                onOpenArrowSettings: () {},
                onOpenEngineSettings: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure no overflow errors were thrown
      expect(tester.takeException(), isNull, reason: 'Overflow occurred at width $width');

      // Verify navigation buttons are present
      expect(find.byIcon(Icons.first_page), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.last_page), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
      expect(find.byIcon(Icons.alt_route), findsOneWidget);

      // On wide screens (>= 350), arrow & engine buttons are shown directly
      if (width >= 350) {
        expect(find.byIcon(Icons.north_east), findsOneWidget);
        expect(find.byIcon(Icons.tune), findsOneWidget);
      } else {
        // On very narrow screens (< 350), more_horiz overflow menu is displayed
        expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      }
    }
  });
}
