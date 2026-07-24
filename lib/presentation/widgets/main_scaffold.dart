/// Main scaffold — bottom navigation with five tabs (Navigation.md):
/// Home, Activities, Map, Archive, Profile. A floating action button for
/// creating an activity is visible on Home and Activities.
import 'package:flutter/material.dart';

import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/activities/activities_page.dart';
import 'package:pokatuha/presentation/activities/create_activity_page.dart';
import 'package:pokatuha/presentation/archive/archive_page.dart';
import 'package:pokatuha/presentation/home/home_page.dart';
import 'package:pokatuha/presentation/map/map_page.dart';
import 'package:pokatuha/presentation/profile/profile_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  static const _pages = <Widget>[
    HomePage(),
    ActivitiesPage(),
    MapPage(),
    ArchivePage(),
    ProfilePage(),
  ];

  bool get _showFab => _index == 0 || _index == 1;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: _showFab
          ? FloatingActionButton.extended(
              onPressed: () => _createActivity(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.createActivity),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_outlined),
            selectedIcon: const Icon(Icons.event_rounded),
            label: l.tabActivities,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map_rounded),
            label: l.tabMap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history_rounded),
            label: l.tabArchive,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l.tabProfile,
          ),
        ],
      ),
    );
  }

  void _createActivity(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateActivityPage()),
    );
  }
}
