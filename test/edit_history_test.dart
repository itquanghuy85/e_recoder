import 'package:e_screen_recorder/features/editor/edit_history_sheet.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_recorder.dart';

EditProject _base() => EditProject.fresh(
  sourceUri: 'content://v/1',
  name: 'a.mp4',
  durationMs: 30000,
  frameW: 720,
  frameH: 1600,
);

({EditorController c, FakeRecorder fake}) _rig() {
  final fake = FakeRecorder();
  final c = EditorController(
    project: _base(),
    native: fake,
    store: MemoryProjectStore(),
    autosaveDelay: const Duration(milliseconds: 10),
  );
  addTearDown(c.dispose);
  addTearDown(fake.controller.close);
  return (c: c, fake: fake);
}

void main() {
  test('each step is named, newest first, and moves to the redo list', () {
    final (:c, fake: _) = _rig();
    c.addText();
    c.addMarker(MarkerType.finger, color: Colors.red);
    expect(c.undoHistory, [EditAction.markers, EditAction.text]);

    c.undo();
    expect(c.undoHistory, [EditAction.text]);
    expect(c.redoHistory, [EditAction.markers]);

    c.redo();
    expect(c.undoHistory, [EditAction.markers, EditAction.text]);
    expect(c.redoHistory, isEmpty);
  });

  test('jumpBack goes back several steps at once', () {
    final (:c, fake: _) = _rig();
    c.addText();
    c.addMarker(MarkerType.finger, color: Colors.red);
    c.addMarker(MarkerType.circle, color: Colors.blue);

    c.jumpBack(2);
    expect(c.undoHistory, [EditAction.text]);
    expect(c.redoHistory, [EditAction.markers, EditAction.markers]);

    // Past the beginning is a no-op, not an error.
    c.jumpBack(10);
    expect(c.canUndo, isFalse);
    expect(c.redoHistory.length, 3);
  });

  testWidgets('the history sheet lists the steps and jumps to one', (
    tester,
  ) async {
    final (:c, fake: _) = _rig();
    c.addText();
    c.addMarker(MarkerType.finger, color: Colors.red);
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.localizationsDelegates,
        locale: const Locale('vi'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEditHistorySheet(context, c),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử chỉnh sửa'), findsOneWidget);
    expect(find.text('Dấu trên màn hình'), findsOneWidget);
    expect(find.text('Chữ và hình'), findsOneWidget);

    // The second row is the older step: jumping there undoes both.
    await tester.tap(find.text('Chữ và hình'));
    await tester.pumpAndSettle();
    expect(c.canUndo, isFalse);
    expect(c.redoHistory.length, 2);
    expect(find.text('Lịch sử chỉnh sửa'), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('an undone step can be brought back from the sheet', (
    tester,
  ) async {
    final (:c, fake: _) = _rig();
    c.addText();
    c.addMarker(MarkerType.finger, color: Colors.red);
    c.undo();
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.localizationsDelegates,
        locale: const Locale('vi'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEditHistorySheet(context, c),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Đã hoàn tác'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Làm lại'));
    await tester.pumpAndSettle();
    expect(c.undoHistory, [EditAction.markers, EditAction.text]);
    await tester.pump(const Duration(milliseconds: 50));
  });
}
