import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/splash_overlay.dart';
import 'app/settings_store.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  runApp(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(settings),
        splashEnabledProvider.overrideWithValue(true),
      ],
      child: const EScreenRecorderApp(),
    ),
  );
}

class EScreenRecorderApp extends ConsumerWidget {
  const EScreenRecorderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      onGenerateTitle: (c) => AppL10n.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      locale: ref.watch(localeProvider),
      // The first supported language of the device wins; anything else falls back to Vietnamese.
      localeListResolutionCallback: (locales, supported) {
        for (final l in locales ?? const <Locale>[]) {
          for (final s in supported) {
            if (s.languageCode == l.languageCode) return s;
          }
        }
        return const Locale('vi');
      },
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          SplashOverlay(child: child ?? const SizedBox.shrink()),
      home: const _Root(),
    );
  }
}

/// First run shows the short introduction; afterwards the app opens on the recorder.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(onboardedProvider);
    return onboarded ? const AppShell() : OnboardingScreen(onDone: () {});
  }
}
