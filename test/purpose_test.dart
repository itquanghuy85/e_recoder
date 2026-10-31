import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:e_screen_recorder/features/marker/marker_settings.dart';
import 'package:e_screen_recorder/features/purpose/purpose.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  group('what each purpose switches', () {
    const base = MarkerSettings();
    test('tutorial: clean recording, listens to taps, marks and zooms', () {
      final m = applyPurposeToMarkers(Purpose.tutorial, base);
      expect(m.mode, MarkMode.clean);
      expect(m.touchSource, TouchSource.auto);
      expect(m.autoNumber, isTrue);
      expect(m.autoZoom, isTrue);
    });

    test('game: marks by hand, no automatic zoom', () {
      final m = applyPurposeToMarkers(
        Purpose.game,
        base.copyWith(mode: MarkMode.clean, autoZoom: true),
      );
      expect(m.mode, MarkMode.dot);
      expect(m.autoZoom, isFalse);
      expect(m.autoNumber, isTrue);
    });

    test('plain: everything automatic is off', () {
      final m = applyPurposeToMarkers(Purpose.plain, base);
      expect(m.mode, MarkMode.dot);
      expect(m.touchSource, TouchSource.off);
      expect(m.autoNumber, isFalse);
      expect(m.autoZoom, isFalse);
    });

    test('the look the person chose is left alone', () {
      final mine = base.copyWith(
        tool: MarkerType.circle,
        colorIndex: 2,
        thickness: 8,
        holdMs: 4000,
        autoMarker: MarkerType.arrow,
      );
      for (final p in Purpose.values) {
        final m = applyPurposeToMarkers(p, mine);
        expect(m.tool, MarkerType.circle);
        expect(m.colorIndex, 2);
        expect(m.thickness, 8);
        expect(m.holdMs, 4000);
        expect(m.autoMarker, MarkerType.arrow);
      }
    });
  });

  testWidgets('first run: the choice is saved, applied and not asked again', (
    tester,
  ) async {
    _phone(tester);
    final (:app, fake: _) = await buildTestApp(onboarded: false);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Làm video hướng dẫn'));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(c.read(purposeProvider), Purpose.tutorial);
    expect(c.read(markerSettingsProvider).mode, MarkMode.clean);
    expect(c.read(markerSettingsProvider).touchSource, TouchSource.auto);
    expect(find.text('Bạn muốn làm gì?'), findsNothing);
  });

  testWidgets('someone already past the introduction is not asked', (
    tester,
  ) async {
    _phone(tester);
    final (:app, fake: _) = await buildTestApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Bạn muốn làm gì?'), findsNothing);
  });

  group('the recorder screen', () {
    Future<void> open(WidgetTester tester, Map<String, Object> prefs) async {
      _phone(tester);
      final (:app, fake: _) = await buildTestApp(prefs: prefs);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
    }

    for (final (p, label) in [
      (Purpose.tutorial, 'Quay hướng dẫn tự động'),
      (Purpose.game, 'Quay game'),
      (Purpose.plain, 'Quay video'),
    ]) {
      testWidgets('one big button says what it does for ${p.name}', (
        tester,
      ) async {
        await open(tester, {'purpose': p.index});
        expect(find.text(label), findsOneWidget);
        expect(find.text('Bắt đầu quay'), findsNothing);
        final size = tester.getSize(find.byKey(const ValueKey('record_start')));
        expect(size.height, greaterThanOrEqualTo(88));
        expect(size.width, greaterThan(300)); // the whole row
      });
    }

    testWidgets('the old controls are folded into Advanced', (tester) async {
      await open(tester, {'purpose': Purpose.tutorial.index});
      expect(find.text('Nâng cao'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_card')), findsNothing);
      await tester.tap(find.text('Nâng cao'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile_card')), findsOneWidget);
      // and the choice can be changed from there
      await tester.tap(find.byKey(const ValueKey('change_purpose')));
      await tester.pumpAndSettle();
      expect(find.text('Bạn muốn làm gì?'), findsOneWidget);
      await tester.tap(find.text('Quay game'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn muốn làm gì?'), findsNothing);
      expect(find.text('Quay game'), findsWidgets); // the big button now
      final c = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      expect(c.read(purposeProvider), Purpose.game);
    });

    testWidgets('the old way is untouched when no purpose was chosen', (
      tester,
    ) async {
      await open(tester, {});
      expect(find.text('Bắt đầu quay'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_card')), findsOneWidget);
      expect(find.text('Nâng cao'), findsNothing);
      // and the choice is offered
      expect(find.byKey(const ValueKey('purpose_offer')), findsOneWidget);
    });
  });
}
