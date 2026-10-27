import 'package:e_screen_recorder/features/splash/splash_overlay.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required bool enabled}) => ProviderScope(
  overrides: [splashEnabledProvider.overrideWithValue(enabled)],
  child: MaterialApp(
    locale: const Locale('vi'),
    supportedLocales: AppL10n.supportedLocales,
    localizationsDelegates: AppL10n.localizationsDelegates,
    home: const SplashOverlay(child: Scaffold(body: Text('APP'))),
  ),
);

void main() {
  setUp(SplashOverlay.resetForTest);

  testWidgets('disabled: the app shows straight away', (tester) async {
    await tester.pumpWidget(_app(enabled: false));
    expect(find.text('APP'), findsOneWidget);
    expect(find.text('E Screen Recorder'), findsNothing);
  });

  testWidgets('enabled: brand intro over the app, then it dissolves', (
    tester,
  ) async {
    await tester.pumpWidget(_app(enabled: true));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('E Screen Recorder'), findsOneWidget);
    expect(
      find.text('Cho người xem biết trước chỗ bạn sắp bấm'),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.text('E Screen Recorder'), findsNothing);
    expect(find.text('APP'), findsOneWidget);
  });

  testWidgets('a tap skips the intro', (tester) async {
    await tester.pumpWidget(_app(enabled: true));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('E Screen Recorder'), findsNothing);
  });
}
