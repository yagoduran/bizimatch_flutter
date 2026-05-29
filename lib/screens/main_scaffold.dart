import 'dart:async';

import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import '../services/feature_tour_service.dart';
import '../services/firestore_service.dart';
import '../widgets/admob_banner.dart';
import '../widgets/feature_tour_action_button.dart';
import 'community_screen.dart';
import 'discover_screen.dart';
import 'home_management_screen.dart';
import 'map_screen.dart';
import 'matches_screen.dart';
import 'profile_detail_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// MainScaffold: aplikazioaren oinarrizko nabigazio egitura.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 4;

  final FirestoreService _firestoreService = FirestoreService();
  final FeatureTourService _featureTourService = FeatureTourService.instance;

  late final TabController _tabController;
  StreamSubscription<List<String>>? _likesSubscription;

  int _currentIndex = 0;
  bool _startingTutorial = false;

  final List<Widget> _screens = const [
    DiscoverScreen(),
    MatchesScreen(),
    CommunityScreen(),
    HomeManagementScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || !mounted) {
        return;
      }
      setState(() {
        _currentIndex = _tabController.index;
      });
    });

    _verificarLikesRecibidos();
    _featureTourService.replayRequests.addListener(_handleTutorialReplay);

    ShowcaseView.register(
      blurValue: 2.4,
      overlayOpacity: 0.72,
      onDismiss: _handleTutorialDismiss,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartTutorial();
    });
  }

  Future<void> _maybeStartTutorial({bool force = false}) async {
    if (_startingTutorial || !mounted) {
      return;
    }

    final shouldStart =
        force || await _featureTourService.shouldAutoStartMainTutorial();
    if (!shouldStart || !mounted) {
      return;
    }

    _startingTutorial = true;
    _selectScreen(0);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) {
      _startingTutorial = false;
      return;
    }

    ShowcaseView.get().startShowCase([
      _featureTourService.discoverCardKey,
      _featureTourService.chatsTabKey,
      _featureTourService.homeTasksExpensesKey,
    ]);
    _startingTutorial = false;
  }

  void _handleTutorialReplay() {
    _maybeStartTutorial(force: true);
  }

  void _handleTutorialDismiss(GlobalKey? key) {
    if (key == _featureTourService.contractPdfButtonKey) {
      _featureTourService.markContractTutorialSeen();
      return;
    }

    final mainKeys = <GlobalKey>{
      _featureTourService.discoverCardKey,
      _featureTourService.chatsTabKey,
      _featureTourService.homeTasksExpensesKey,
    };
    if (key == null || mainKeys.contains(key)) {
      _featureTourService.markMainTutorialSeen();
    }
  }

  void _verificarLikesRecibidos() {
    _likesSubscription?.cancel();
    _likesSubscription = _firestoreService.obtenerLikesNoLeidos().listen(
      (likesFromIds) {
        if (!mounted || likesFromIds.isEmpty) {
          return;
        }
        _mostrarDialogLikesRecibidos(likesFromIds.first);
      },
      onError: (error) {
        debugPrint('Error verificando likes: $error');
      },
    );
  }

  void _mostrarDialogLikesRecibidos(String likerUid) {
    showDialog<void>(
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
                            builder: (_) => ProfileDetailScreen(userUid: likerUid),
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

  void _selectScreen(int index) {
    if (index < 0 || index >= _tabCount || _currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
    _tabController.animateTo(index);
  }

  int _bottomIndexFor(int tabIndex) => tabIndex.clamp(0, _tabCount - 1);

  Future<void> _openMoreMenu() async {
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: const Text('Perfil'),
                  subtitle: const Text('Editar información personal'),
                  onTap: () => Navigator.pop(context, 0),
                ),
                ListTile(
                  leading: const Icon(Icons.map_rounded),
                  title: const Text('Mapa'),
                  subtitle: const Text('Ver usuarios y lugares cercanos'),
                  onTap: () => Navigator.pop(context, 1),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_rounded),
                  title: const Text('Ajustes'),
                  subtitle: const Text('Privacidad, notificaciones y ayuda'),
                  onTap: () => Navigator.pop(context, 2),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedIndex == null) {
      return;
    }

    switch (selectedIndex) {
      case 0:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
        );
        break;
      case 1:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MapScreen()),
        );
        break;
      case 2:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
        );
        break;
    }
  }

  List<TooltipActionButton> _buildChatsTooltipActions() {
    return [
      TooltipActionButton.custom(
        button: FeatureTourActionButton(
          label: 'Saltar',
          onTap: () {
            _featureTourService.markMainTutorialSeen();
            ShowcaseView.get().dismiss();
          },
        ),
      ),
      TooltipActionButton.custom(
        button: FeatureTourActionButton(
          label: 'Siguiente',
          primary: true,
          onTap: () => ShowcaseView.get().next(force: true),
        ),
      ),
    ];
  }

  Widget _buildBottomNavigation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdmobBanner(),
        BottomNavigationBar(
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
          items: [
            BottomNavigationBarItem(
              icon: Semantics(
                button: true,
                label: 'Explorar / Arakatu',
                hint: 'Abre la pantalla para descubrir perfiles',
                child: const ExcludeSemantics(
                  child: Icon(Icons.travel_explore_rounded),
                ),
              ),
              label: 'Explorar',
            ),
            BottomNavigationBarItem(
              icon: Showcase(
                key: _featureTourService.chatsTabKey,
                title: 'Rompe el hielo con BiziBot',
                description:
                    'Nuestra IA analiza los perfiles y te da preguntas personalizadas para empezar a hablar sin vergüenza.',
                titleTextStyle: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                descTextStyle: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 14,
                  height: 1.45,
                ),
                tooltipBackgroundColor: Colors.white,
                tooltipPadding: const EdgeInsets.all(18),
                tooltipActionConfig: const TooltipActionConfig(
                  alignment: MainAxisAlignment.spaceBetween,
                  position: TooltipActionPosition.inside,
                  gapBetweenContentAndAction: 14,
                ),
                tooltipBorderRadius: BorderRadius.circular(24),
                targetPadding: const EdgeInsets.all(8),
                overlayColor: Colors.black,
                overlayOpacity: 0.72,
                disableDefaultTargetGestures: true,
                tooltipActions: _buildChatsTooltipActions(),
                child: Semantics(
                  button: true,
                  label: 'Vínculos y chats / Loturak eta txatak',
                  hint: 'Abre tus conversaciones y conexiones',
                  child: ExcludeSemantics(
                    child: Icon(Icons.chat_bubble_rounded),
                  ),
                ),
              ),
              label: 'Vínculos',
            ),
            BottomNavigationBarItem(
              icon: Semantics(
                button: true,
                label: 'Comunidad / Komunitatea',
                hint: 'Abre los planes y actividades compartidas',
                child: ExcludeSemantics(child: Icon(Icons.groups_rounded)),
              ),
              label: 'Comunidad',
            ),
            BottomNavigationBarItem(
              icon: Semantics(
                button: true,
                label: 'Mi casa / Nire etxea',
                hint: 'Gestiona tareas y gastos del hogar',
                child: ExcludeSemantics(child: Icon(Icons.home_rounded)),
              ),
              label: 'Casa',
            ),
            BottomNavigationBarItem(
              icon: Semantics(
                button: true,
                label: 'Más opciones / Aukera gehiago',
                hint: 'Abre perfil, mapa y ajustes',
                child: ExcludeSemantics(child: Icon(Icons.more_horiz_rounded)),
              ),
              label: 'Más',
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _likesSubscription?.cancel();
    _featureTourService.replayRequests.removeListener(_handleTutorialReplay);
    ShowcaseView.get().unregister();
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
          for (var i = 0; i < _screens.length; i++) _buildTabBody(_screens[i], i),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildTabBody(Widget screen, int index) {
    if (index == 0) {
      return screen;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(
        key: ValueKey<int>(index),
        child: screen,
      ),
    );
  }
}
