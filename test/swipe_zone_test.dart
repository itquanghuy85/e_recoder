import 'package:e_screen_recorder/features/editor/swipe_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<bool>> _pump(
  WidgetTester tester, {
  bool Function()? enabled,
  Widget? inside,
}) async {
  final got = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: SwipeZone(
              onSwipe: got.add,
              enabled: enabled ?? () => true,
              child: inside ?? const ColoredBox(color: Colors.grey),
            ),
          ),
        ),
      ),
    ),
  );
  return got;
}

void main() {
  group('EditorSpace', () {
    test('a swipe down gives more room, one more gives the whole screen', () {
      expect(EditorSpace.normal.swiped(down: true), EditorSpace.workspace);
      expect(EditorSpace.workspace.swiped(down: true), EditorSpace.full);
      expect(EditorSpace.full.swiped(down: true), EditorSpace.full);
    });

    test('a swipe up gives it back, one step at a time', () {
      expect(EditorSpace.full.swiped(down: false), EditorSpace.workspace);
      expect(EditorSpace.workspace.swiped(down: false), EditorSpace.normal);
      expect(EditorSpace.normal.swiped(down: false), EditorSpace.normal);
    });
  });

  group('SwipeZone', () {
    testWidgets('a quick swipe down and a quick swipe up are heard', (t) async {
      final got = await _pump(t);
      await t.fling(find.byType(SwipeZone), const Offset(0, 160), 1500);
      await t.fling(find.byType(SwipeZone), const Offset(0, -160), 1500);
      expect(got, [true, false]);
    });

    testWidgets('a sideways stroke (scrubbing) is not a swipe', (t) async {
      final got = await _pump(t);
      await t.fling(find.byType(SwipeZone), const Offset(200, 20), 1500);
      await t.fling(find.byType(SwipeZone), const Offset(150, 150), 1500);
      expect(got, isEmpty);
    });

    testWidgets('a short move is not a swipe', (t) async {
      final got = await _pump(t);
      await t.drag(find.byType(SwipeZone), const Offset(0, 40));
      expect(got, isEmpty);
    });

    testWidgets('a slow drag is not a swipe', (t) async {
      final got = await _pump(t);
      final from = t.getCenter(find.byType(SwipeZone));
      final p = TestPointer(1);
      await t.sendEventToBinding(p.down(from, timeStamp: Duration.zero));
      await t.sendEventToBinding(
        p.move(
          from + const Offset(0, 100),
          timeStamp: const Duration(seconds: 1),
        ),
      );
      await t.sendEventToBinding(p.up(timeStamp: const Duration(seconds: 1)));
      expect(got, isEmpty);
      // the same stroke, quick, is heard
      await t.sendEventToBinding(p.down(from, timeStamp: Duration.zero));
      await t.sendEventToBinding(
        p.move(
          from + const Offset(0, 100),
          timeStamp: const Duration(milliseconds: 150),
        ),
      );
      await t.sendEventToBinding(
        p.up(timeStamp: const Duration(milliseconds: 150)),
      );
      expect(got, [true]);
    });

    testWidgets('two fingers (pinch) are not a swipe', (t) async {
      final got = await _pump(t);
      final c = t.getCenter(find.byType(SwipeZone));
      final a = await t.startGesture(c + const Offset(-30, 0));
      final b = await t.startGesture(c + const Offset(30, 0));
      await a.moveBy(const Offset(0, 160));
      await b.moveBy(const Offset(0, 160));
      await a.up();
      await b.up();
      expect(got, isEmpty);
    });

    testWidgets('not heard while the editor says no (something selected)', (
      t,
    ) async {
      var ok = false;
      final got = await _pump(t, enabled: () => ok);
      await t.fling(find.byType(SwipeZone), const Offset(0, 160), 1500);
      expect(got, isEmpty);
      ok = true;
      await t.fling(find.byType(SwipeZone), const Offset(0, 160), 1500);
      expect(got, [true]);
    });

    testWidgets('the child keeps its own taps and drags', (t) async {
      var taps = 0;
      var dragged = 0.0;
      final got = await _pump(
        t,
        inside: GestureDetector(
          onTap: () => taps++,
          onHorizontalDragUpdate: (d) => dragged += d.delta.dx,
          child: const ColoredBox(color: Colors.grey),
        ),
      );
      await t.tap(find.byType(SwipeZone));
      await t.drag(find.byType(SwipeZone), const Offset(120, 0));
      expect(taps, 1);
      expect(dragged, greaterThan(50));
      expect(got, isEmpty);
    });
  });
}
