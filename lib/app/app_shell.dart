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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final index = ref.watch(shellIndexProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: index,
          children: const [RecordScreen(), LibraryScreen(), SettingsScreen()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref.read(shellIndexProvider.notifier).go,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.fiber_manual_record_outlined),
            selectedIcon: const Icon(Icons.fiber_manual_record),
            label: t.navRecord,
          ),
          NavigationDestination(
            icon: const Icon(Icons.video_library_outlined),
            selectedIcon: const Icon(Icons.video_library),
            label: t.navLibrary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune),
            label: t.navSettings,
          ),
        ],
      ),
    );
  }
}
