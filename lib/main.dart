import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';
import 'state/tab_bus.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState(
    settingsService: SettingsService(),
    storageService: StorageService(),
  );
  await appState.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<TabBus>(create: (_) => TabBus()),
      ],
      child: const NabuInventApp(),
    ),
  );
}

class NabuInventApp extends StatelessWidget {
  const NabuInventApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final idx = app.settings.accentIndex
        .clamp(0, AppThemes.accentSeeds.length - 1);
    final seed = AppThemes.accentSeeds[idx];

    return MaterialApp(
      title: 'NabuInvent AI',
      debugShowCheckedModeBanner: false,
      themeMode: app.settings.themeMode,
      theme: AppThemes.light(seed),
      darkTheme: AppThemes.dark(seed),
      home: app.settings.onboarded ? const MainShell() : const OnboardingScreen(),
    );
  }
}