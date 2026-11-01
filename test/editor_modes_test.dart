import 'package:e_screen_recorder/features/editor/auto_director.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/editor_tools.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/features/marker/marker_spec.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'helpers/fake_recorder.dart';

Widget _host(
  EditorController c, {
  required bool advanced,
  ValueChanged<bool>? on,
}) => MaterialApp(
  locale: const Locale('vi'),
  supportedLocales: AppL10n.supportedLocales,
  localizationsDelegates: AppL10n.localizationsDelegates,
  home: Scaffold(
    body: SingleChildScrollView(
      child: EditorTools(
        controller: c,
        tool: EditorTool.cut,
        onTool: (_) {},
        newMarkerColor: Colors.red,
        newMarkerThickness: 5,
        video: VideoPlayerController.networkUrl(Uri.parse('file:///x.mp4')),
        advanced: advanced,
        onAdvanced: on,
        onExport: () {},
      ),
    ),
  ),
);

void main() {
  late EditorController c;
  setUp(() {
    final base = EditProject.fresh(
      sourceUri: 'content://v/1',
      name: 'a.mp4',
      durationMs: 20000,
      frameW: 720,
      frameH: 1600,
    );
    c = EditorController(
      project: base.copyWith(
        markers: [
          MarkerItem(
            id: 'a',
            cueStartMs: 1000,
            spec: AutoDirector.tapSpec(
              MarkerType.number,
              0.3,
              0.4,
              1,
              frameW: 720,
              frameH: 1600,
            ),
          ),
        ],
      ),
      native: FakeRecorder(),
      store: MemoryProjectStore(),
      autosaveDelay: const Duration(milliseconds: 10),
    );
  });
  tearDown(() => c.dispose());

  test('Basic is the five everyday tools (Export is the sixth tab); Advanced adds six', () {
    expect(basicTools, [
      EditorTool.cut,
      EditorTool.marker,
      EditorTool.text,
      EditorTool.speed,
      EditorTool.audio,
    ]);
    expect(advancedTools, [
      EditorTool.transition,
      EditorTool.picture,
      EditorTool.overlay,
      EditorTool.cover,
      EditorTool.zoom,
      EditorTool.auto,
    ]);
    // every tool is in exactly one of the two lists
    expect({...basicTools, ...advancedTools}, EditorTool.values.toSet());
  });

  testWidgets('Basic shows six tabs and hides the advanced tools', (
    tester,
  ) async {
    await tester.pumpWidget(_host(c, advanced: false));
    for (final id in [
      'tool_cut',
      'tool_marker',
      'tool_text',
      'tool_speed',
      'tool_audio',
      'tool_export',
    ]) {
      expect(
        find.byKey(const ValueKey('x')),
        findsNothing,
      ); // keep the finder API honest
      expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
    }
    for (final e in advancedTools) {
      expect(find.bySemanticsIdentifier('tool_${e.name}'), findsNothing);
    }
    expect(find.text('Cơ bản'), findsOneWidget);
    expect(find.text('Nâng cao'), findsOneWidget);
  });

  testWidgets('Advanced shows all twelve, and the chips report the choice', (
    tester,
  ) async {
    bool? picked;
    await tester.pumpWidget(_host(c, advanced: true, on: (v) => picked = v));
    for (final e in EditorTool.values) {
      expect(find.bySemanticsIdentifier('tool_${e.name}'), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('editor_mode_basic')));
    expect(picked, isFalse);
    await tester.tap(find.byKey(const ValueKey('editor_mode_advanced')));
    expect(picked, isTrue);
  });

  testWidgets('switching the mode only changes what is shown, not the edit', (
    tester,
  ) async {
    final before = c.project;
    await tester.pumpWidget(_host(c, advanced: true));
    await tester.pumpWidget(_host(c, advanced: false));
    await tester.pumpWidget(_host(c, advanced: true));
    expect(identical(c.project, before), isTrue);
    expect(c.project.markers.length, 1);
  });
}
