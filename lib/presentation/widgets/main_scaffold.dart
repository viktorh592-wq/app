/// Main scaffold — bottom navigation with four tabs (V2
/// ARCHITECTURE_V2.md §6): Groups / Map / Archive / Profile. The FAB
/// depends on the active tab: «Add Group» on Groups, the map action menu on
/// Map (handled inside MapPage), hidden elsewhere. Users never create
/// standalone activities from here (GROUPS_AND_ACTIVITIES.md §1) — the
/// «Add Activity» FAB lives inside GroupDetailPage.
import 'package:flutter/material.dart';

import 'package:pokatuha/presentation/archive/archive_page.dart';
import 'package:pokatuha/presentation/groups/groups_page.dart';
import 'package:pokatuha/presentation/map/map_page.dart';
import 'package:pokatuha/presentation/profile/profile_page.dart';
import 'package:pokatuha/presentation/widgets/bottom_nav_bar.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  // Exactly four tabs (ARCHITECTURE_V2.md §6): Groups, Map, Archive,
  // Profile. The FAB slot in the middle of the nav is represented by the
  // per-tab FAB behaviour: Groups shows «Add Group»; Map shows the map
  // action menu FAB (inside MapPage).
  static const _pages = <Widget>[
    GroupsPage(),
    MapPage(),
    ArchivePage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      // V2 lime pill navigation bar (FIX_PLAN S2-T3) instead of the Material
      // NavigationBar.
      bottomNavigationBar: BottomNavBarV2(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
