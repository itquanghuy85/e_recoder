import 'package:e_screen_recorder/core/platform_support.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/editor_tools.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'helpers/fake_recorder.dart';

Widget _host(EditorController c, EditorTool tool) => MaterialApp(
  locale: const Locale('vi'),
  supportedLocales: AppL10n.supportedLocales,
  localizationsDelegates: AppL10n.localizationsDelegates,
  home: Scaffold(
    body: SingleChildScrollView(
      child: EditorTools(
        controller: c,
        tool: tool,
        onTool: (_) {},
        newMarkerColor: Colors.red,
        newMarkerThickness: 5,
        video: VideoPlayerController.networkUrl(Uri.parse('file:///x.mp4')),
        advanced: true,
        onAdvanced: (_) {},
        onExport: () {},
      ),
    ),
  ),
);

Future<void> _asIos(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  late EditorController c;
  setUp(() {
    c = EditorController(
      project: EditProject.fresh(
        sourceUri: 'content://v/1',
        name: 'a.mp4',
        durationMs: 20000,
        frameW: 720,
        frameH: 1600,
      ),
      native: FakeRecorder(),
      store: MemoryProjectStore(),
      autosaveDelay: const Duration(milliseconds: 10),
    );
  });
  tearDown(() => c.dispose());

  for (final (tool, gets) in [
    (EditorTool.transition, 'chuyển cảnh mượt'),
    (EditorTool.zoom, 'phóng to vào chỗ quan trọng'),
    (EditorTool.auto, 'dựng tự động'),
  ]) {
    testWidgets(
      'iPhone: ${tool.name} says it is Android only and what it gives',
      (tester) async {
        await _asIos(() async {
          await tester.pumpWidget(_host(c, tool));
          await tester.pump();
          expect(find.byType(AndroidOnlyPanel), findsOneWidget);
          expect(find.textContaining('chỉ có trên Android'), findsOneWidget);
          expect(find.textContaining(gets), findsOneWidget);
          expect(find.textContaining('Trên Android bạn được'), findsOneWidget);
        });
      },
    );
  }

  for (final tool in [
    EditorTool.speed,
    EditorTool.picture,
    EditorTool.overlay,
    EditorTool.cover,
  ]) {
    testWidgets('iPhone: ${tool.name} works, with a note on what it lacks', (
      tester,
    ) async {
      await _asIos(() async {
        await tester.pumpWidget(_host(c, tool));
        await tester.pump();
        expect(find.byType(AndroidOnlyNote), findsOneWidget);
        expect(find.byType(AndroidOnlyPanel), findsNothing);
        expect(
          find.textContaining('Phần này chỉ có trên Android'),
          findsOneWidget,
        );
      });
    });
  }

  for (final tool in [
    EditorTool.cut,
    EditorTool.marker,
    EditorTool.text,
    EditorTool.audio,
  ]) {
    testWidgets('iPhone: ${tool.name} has nothing to flag', (tester) async {
      await _asIos(() async {
        await tester.pumpWidget(_host(c, tool));
        await tester.pump();
        expect(find.textContaining('Android'), findsNothing);
      });
    });
  }

  testWidgets('Android: no tool carries a note', (tester) async {
    for (final tool in EditorTool.values) {
      await tester.pumpWidget(_host(c, tool));
      await tester.pump();
      expect(find.byType(AndroidOnlyPanel), findsNothing, reason: tool.name);
      expect(find.byType(AndroidOnlyNote), findsNothing, reason: tool.name);
      expect(find.byType(AndroidBadge), findsNothing, reason: tool.name);
    }
  });
}
