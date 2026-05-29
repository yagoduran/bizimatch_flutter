import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:showcaseview/showcaseview.dart';

import '../app_theme.dart';
import '../services/feature_tour_service.dart';
import '../services/firestore_service.dart';
import '../widgets/admob_banner.dart';
import '../widgets/feature_tour_action_button.dart';
import 'community_screen.dart';
import 'discover_screen.dart';
import 'home_management_screen.dart';
import 'map_screen.dart';
import 'matches_screen.dart';
import 'profile_screen.dart';
import 'profile_detail_screen.dart';
import 'settings_screen.dart';
import '../widgets/glassmorphism.dart';

/// MainScaffold: aplikazioaren oinarrizko nabigazio egitura (tabs eta behe-menua).
///
/// Barruan aurkitzen dira: Arakatu, Vínculos, Komunitatea, Nire etxea, Perfil eta mapa.
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
  final FeatureTourService _featureTourService = FeatureTourService.instance;
  bool _startingTutorial = false;

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

  /// Tutorial automatikoa abiarazteko kontrola: beharrezkoa bada Showcase hasi.
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
    // Pantaila lehenengora alda eta tutorial pausuz pausu erakutsi
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
          onTap: () async {
            _selectScreen(3);
            await Future<void>.delayed(const Duration(milliseconds: 550));
            if (!mounted) {
              return;
            }
            ShowcaseView.get().next(force: true);
          },
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AdmobBanner(),
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
                      child: ExcludeSemantics(
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
                      tooltipActions: [
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
                      ],
                      child: const Icon(Icons.chat_bubble_rounded),
                    ),
                    label: 'Vínculos',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.groups_rounded),
                    label: 'Comunidad',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded),
                    label: 'Mi casa',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_rounded),
                    label: 'Perfil',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.map_rounded),
                    label: 'Mapa',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_rounded),
                    label: 'Ajustes',
                  ),
                ],
              ),
            ],
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
          for (var i = 0; i < _screens.length; i++)
            _buildTabBody(_screens[i], i),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdmobBanner(),
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
                  child: ExcludeSemantics(
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
                    child: ExcludeSemantics(child: Icon(Icons.groups_rounded)),
                  ),
                ),
                label: 'Vínculos',
              ),
              BottomNavigationBarItem(
                icon: Semantics(
                  button: true,
                  label: 'Comunidad / Komunitatea',
                  hint: 'Abre los planes y actividades compartidas',
                  child: ExcludeSemantics(child: Icon(Icons.local_bar_outlined)),
                ),
                label: 'Comunidad',
              ),
              BottomNavigationBarItem(
                icon: Semantics(
                  button: true,
                  label: 'Mi casa / Nire etxea',
                  hint: 'Gestiona tareas y gastos del hogar',
                  child: ExcludeSemantics(child: Icon(Icons.home_work_outlined)),
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
