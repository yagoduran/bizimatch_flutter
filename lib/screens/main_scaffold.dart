import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import 'discover_screen.dart';
import 'map_screen.dart';
import 'matches_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final TabController _tabController;

  final _screens = const [
    DiscoverScreen(),
    MatchesScreen(),
    ProfileScreen(),
    MapScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _screens.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        return;
      }
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        physics: _currentIndex == 0
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          HapticFeedback.selectionClick();
          setState(() {
            _currentIndex = index;
          });
          _tabController.animateTo(
            index,
            duration: AppTheme.motionNavigation,
            curve: AppTheme.motionCurveEmphasized,
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.travel_explore_rounded),
            label: 'Explorar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_rounded),
            label: 'Vínculos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Perfil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
