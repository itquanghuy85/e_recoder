import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

void _screen(WidgetTester tester, Size dp) {
  tester.view.physicalSize = dp * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  for (final (name, size, rail) in [
    ('phone portrait', const Size(390, 860), false),
    ('Z Flip cover / small', const Size(360, 380), false),
    ('phone landscape', const Size(860, 390), true),
    ('Z Fold opened', const Size(820, 900), true),
    ('tablet landscape', const Size(1280, 800), true),
  ]) {
    testWidgets('$name: ${rail ? 'side rail' : 'bottom bar'}, tabs work, nothing overflows', (
      tester,
    ) async {
      _screen(tester, size);
      final (:app, fake: _) = await buildTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), rail ? findsOneWidget : findsNothing);
      expect(find.byType(NavigationBar), rail ? findsNothing : findsOneWidget);
      // Pages keep a readable width on big screens.
      final page = tester.getSize(find.byType(IndexedStack));
      expect(page.width, lessThanOrEqualTo(760));
      await tester.tap(find.text('Thư viện'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
