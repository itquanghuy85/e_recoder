import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/library/library_screen.dart';
import '../features/record/record_screen.dart';
import '../features/settings/settings_screen.dart';
import '../l10n/app_localizations.dart';
import 'shell_provider.dart';

/// Bottom navigation: Quay / Thư viện / Cài đặt. Tabs are kept alive so the
/// recorder state is not lost while browsing the library.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  /// Wider than this (a Fold opened, a tablet, a phone turned sideways) the tabs move to a rail on
  /// the left and the pages keep a readable width instead of stretching across the screen.
  static const wideFrom = 600.0;
  static const maxContent = 760.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final index = ref.watch(shellIndexProvider);
    final go = ref.read(shellIndexProvider.notifier).go;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= wideFrom || size.width > size.height;
    final dest = [
      (Icons.fiber_manual_record_outlined, Icons.fiber_manual_record, t.navRecord),
      (Icons.video_library_outlined, Icons.video_library, t.navLibrary),
      (Icons.tune_outlined, Icons.tune, t.navSettings),
    ];
    final pages = SafeArea(
      bottom: wide,
      left: !wide,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContent),
          child: IndexedStack(
            index: index,
            children: const [RecordScreen(), LibraryScreen(), SettingsScreen()],
          ),
        ),
      ),
    );
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: index,
                onDestinationSelected: go,
                labelType: NavigationRailLabelType.all,
                groupAlignment: 0,
                destinations: [
                  for (final (i, si, l) in dest)
                    NavigationRailDestination(
                      icon: Icon(i),
                      selectedIcon: Icon(si),
                      label: Text(l),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages),
          ],
        ),
      );
    }
    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: [
          for (final (i, si, l) in dest)
            NavigationDestination(
              icon: Icon(i),
              selectedIcon: Icon(si),
              label: l,
            ),
        ],
      ),
    );
  }
}
