import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/tab_bus.dart';
import 'home_screen.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';
import 'sparks_screen.dart';
import 'studio_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  final pages = const [
    HomeScreen(),
    ProjectsScreen(),
    StudioScreen(),
    SparksScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bus = context.watch<TabBus>();
    return Scaffold(
      body: IndexedStack(index: bus.index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bus.index,
        onDestinationSelected: bus.go,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 70,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Projets',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'Studio',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Étincelles',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune),
            selectedIcon: Icon(Icons.tune),
            label: 'Réglages',
          ),
        ],
      ),
    );
  }
}