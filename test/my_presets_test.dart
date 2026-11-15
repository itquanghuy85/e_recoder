import 'package:e_screen_recorder/app/settings_store.dart';
import 'package:e_screen_recorder/features/editor/edit_project.dart';
import 'package:e_screen_recorder/features/editor/editor_controller.dart';
import 'package:e_screen_recorder/features/editor/export_presets.dart';
import 'package:e_screen_recorder/features/editor/export_sheet.dart';
import 'package:e_screen_recorder/features/editor/project_store.dart';
import 'package:e_screen_recorder/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_recorder.dart';

const _a = UserExportPreset(
  id: 'a',
  name: 'TikTok nhẹ',
  quality: ExportQuality.p720,
  maxBytes: 20 * 1024 * 1024,
  aspect: OutAspect.r9x16,
);
const _b = UserExportPreset(id: 'b', name: 'Động nhẹ', gif: true);

void main() {
  group('model', () {
    test('round trip keeps every field; missing ones fall back', () {
      final l = const UserPresetList([_a, _b], defaultId: 'a');
      final back = UserPresetList.decode(l.encode());
      expect(back.items.length, 2);
      final a = back.items.first;
      expect(a.name, 'TikTok nhẹ');
      expect(a.quality, ExportQuality.p720);
      expect(a.maxBytes, 20 * 1024 * 1024);
      expect(a.aspect, OutAspect.r9x16);
      expect(back.items.last.gif, isTrue);
      expect(back.items.last.aspect, isNull);
      expect(back.defaultPreset?.id, 'a');
    });

    test('nothing stored, junk, or an unknown value never breaks the sheet', () {
      expect(UserPresetList.decode(null).items, isEmpty);
      expect(UserPresetList.decode('not json').items, isEmpty);
      final odd = UserPresetList.decode(
        '{"items":[{"id":"x","name":"X","quality":"p4k","aspect":"r21x9"},'
        '{"id":"y"},{"name":"no id"}],"default":"gone"}',
      );
      expect(odd.items.single.quality, ExportQuality.original);
      expect(odd.items.single.aspect, isNull);
      expect(odd.defaultId, isNull);
    });

    test('upsert, rename, duplicate, delete, default on/off, capped list', () {
      var l = const UserPresetList([]).upsert(_a).upsert(_b);
      l = l.withDefault('a');
      expect(l.defaultPreset?.id, 'a');
      l = l.upsert(_a.copyWith(name: 'Đổi tên'));
      expect(l.items.first.name, 'Đổi tên');
      expect(l.items.length, 2);
      l = l.duplicate('a', 'c', 'Đổi tên (bản sao)');
      expect(l.items.last.quality, ExportQuality.p720);
      expect(l.items.last.id, 'c');
      l = l.withDefault('a'); // the same again clears it
      expect(l.defaultId, isNull);
      l = l.withDefault('c').remove('c');
      expect(l.defaultId, isNull);
      for (var i = 0; i < 20; i++) {
        l = l.upsert(UserExportPreset(id: 'n$i', name: 'N$i'));
      }
      expect(l.items.length, UserPresetList.maxItems);
      expect(l.items.last.id, 'n19');
    });

    test('a saved preset plans like the built-in ones, never above the bitrate ceiling', () {
      for (final q in ExportQuality.values) {
        final plan = ExportPlanner.plan(
          frameW: 3120,
          frameH: 1440,
          durationMs: 60000,
          quality: q,
          maxBytes: _a.maxBytes,
          sourceFps: 60,
        );
        expect(plan.bitrate, lessThanOrEqualTo(ExportPlanner.maxVideoBitrate));
        expect(plan.estimatedBytes, lessThanOrEqualTo(_a.maxBytes! * 1.03));
      }
    });
  });

  group('export sheet', () {
    Future<(EditorController, SettingsStore)> open(
      WidgetTester tester, [
      Map<String, Object> prefs = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(prefs);
      final store = await SettingsStore.load();
      final fake = FakeRecorder();
      addTearDown(fake.controller.close);
      final c = EditorController(
        project: EditProject.fresh(
          sourceUri: 'content://v/1',
          name: 'a.mp4',
          durationMs: 30000,
          frameW: 1080,
          frameH: 2400,
        ),
        native: fake,
        store: MemoryProjectStore(),
        autosaveDelay: const Duration(milliseconds: 10),
      );
      addTearDown(c.dispose);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            supportedLocales: AppL10n.supportedLocales,
            localizationsDelegates: AppL10n.localizationsDelegates,
            locale: const Locale('vi'),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => showExportSheet(ctx, c),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (c, store);
    }

    testWidgets('save the current settings under a name; it is stored', (
      tester,
    ) async {
      final (c, store) = await open(tester);
      c.setAspect(OutAspect.r1x1);
      await tester.tap(find.text('720p'));
      await tester.pump();
      await tester.tap(find.text('Lưu thiết lập này'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('my_preset_name')), 'Vuông');
      await tester.tap(find.byKey(const ValueKey('my_preset_name_ok')));
      await tester.pumpAndSettle();
      final l = UserPresetList.decode(store.getString(UserPresetList.key));
      expect(l.items.single.name, 'Vuông');
      expect(l.items.single.quality, ExportQuality.p720);
      expect(l.items.single.aspect, OutAspect.r1x1);
      expect(find.widgetWithText(ChoiceChip, 'Vuông'), findsOneWidget);
    });

    testWidgets('the default preset is picked when the sheet opens, shape included', (
      tester,
    ) async {
      final (c, _) = await open(tester, {
        UserPresetList.key: const UserPresetList(
          [_a, _b],
          defaultId: 'a',
        ).encode(),
      });
      await tester.pumpAndSettle();
      expect(c.project.look.aspect, OutAspect.r9x16);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'TikTok nhẹ'),
      );
      expect(chip.selected, isTrue);
      final q = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '720p'));
      expect(q.selected, isTrue);
    });

    testWidgets('long-press: make default, then delete', (tester) async {
      final (_, store) = await open(tester, {
        UserPresetList.key: const UserPresetList([_a, _b]).encode(),
      });
      await tester.longPress(find.widgetWithText(ChoiceChip, 'Động nhẹ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my_preset_default')));
      await tester.pumpAndSettle();
      expect(
        UserPresetList.decode(store.getString(UserPresetList.key)).defaultId,
        'b',
      );
      await tester.longPress(find.widgetWithText(ChoiceChip, 'Động nhẹ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my_preset_delete')));
      await tester.pumpAndSettle();
      final l = UserPresetList.decode(store.getString(UserPresetList.key));
      expect(l.items.map((e) => e.id), ['a']);
      expect(l.defaultId, isNull);
    });
  });
}
