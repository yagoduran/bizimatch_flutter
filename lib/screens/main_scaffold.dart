import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_theme.dart';
import '../services/demo_service.dart';
import '../services/firestore_service.dart';
import 'community_screen.dart';
import 'discover_screen.dart';
import 'home_management_screen.dart';
import 'map_screen.dart';
import 'matches_screen.dart';
import 'profile_screen.dart';
import 'profile_detail_screen.dart';
import 'settings_screen.dart';
import '../widgets/glassmorphism.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _loadingRevision = 0;
  late final TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  final _screens = const [
    DiscoverScreen(),
    MatchesScreen(),
    CommunityScreen(),
    HomeManagementScreen(),
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

    // Verificar likes no leídos al iniciar
    DemoService.instance.isDemoMode.addListener(_syncDemoWakelock);
    _syncDemoWakelock();
    _verificarLikesRecibidos();
  }

  Future<void> _syncDemoWakelock() async {
    if (DemoService.instance.isDemoMode.value) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  bool _shouldFakeLoad(int index) => index == 1 || index == 3;

  int _bottomIndexFor(int screenIndex) {
    if (screenIndex <= 3) {
      return screenIndex;
    }
    return 4;
  }

  void _selectScreen(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
      if (_shouldFakeLoad(index)) {
        _loadingRevision++;
      }
    });
    _tabController.animateTo(
      index,
      duration: AppTheme.motionNavigation,
      curve: AppTheme.motionCurveEmphasized,
    );
  }

  Future<void> _openMoreMenu() async {
    HapticFeedback.selectionClick();
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _MoreMenuTile(
                    index: 4,
                    icon: Icons.person_outline_rounded,
                    title: 'Perfil',
                    subtitle: 'Tu identidad y progreso',
                  ),
                  _MoreMenuTile(
                    index: 5,
                    icon: Icons.map_outlined,
                    title: 'Mapa',
                    subtitle: 'Pisos y servicios cercanos',
                  ),
                  _MoreMenuTile(
                    index: 6,
                    icon: Icons.tune_rounded,
                    title: 'Ajustes',
                    subtitle: 'Demo, notificaciones y privacidad',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      _selectScreen(selected);
    }
  }

  Widget _buildTabBody(Widget screen, int index) {
    if (!_shouldFakeLoad(index)) {
      return screen;
    }

    return FutureBuilder<void>(
      key: ValueKey<String>('fake-load-$index-$_loadingRevision'),
      future: Future<void>.delayed(const Duration(milliseconds: 500)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ShimmerSkeleton(itemCount: 5);
        }
        return screen;
      },
    );
  }

  Future<void> _verificarLikesRecibidos() async {
    try {
      // Pequeño delay para asegurar que el widget esté montado
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Obtener los primeros likes no leídos
      final likesStream = _firestoreService.obtenerLikesNoLeidos();
      likesStream.listen((likesFromIds) {
        if (likesFromIds.isNotEmpty && mounted) {
          _mostrarDialogLikesRecibidos(likesFromIds.first);
        }
      });
    } catch (e) {
      debugPrint('Error verificando likes: $e');
    }
  }

  void _mostrarDialogLikesRecibidos(String likerUid) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF10B981).withValues(alpha: 0.9),
                const Color(0xFF0D9B6F),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_rounded, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                '¡Alguien tiene interés en ti!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Alguien dio me gusta a tu perfil 🏠',
                style: TextStyle(fontSize: 14, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Después'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProfileDetailScreen(userUid: likerUid),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF10B981),
                      ),
                      child: const Text(
                        'Ver Perfil',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    DemoService.instance.isDemoMode.removeListener(_syncDemoWakelock);
    WakelockPlus.disable();
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
        children: [
          for (var i = 0; i < _screens.length; i++)
            _buildTabBody(_screens[i], i),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndexFor(_currentIndex),
        showUnselectedLabels: false,
        selectedFontSize: 12,
        unselectedFontSize: 0,
        onTap: (index) {
          if (index == 4) {
            _openMoreMenu();
            return;
          }
          _selectScreen(index);
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
            icon: Icon(Icons.local_bar_outlined),
            label: 'Comunidad',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_work_outlined),
            label: 'Casa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  const _MoreMenuTile({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: AppTheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.pop(context, index),
    );
  }
}
