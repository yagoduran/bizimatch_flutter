import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with TickerProviderStateMixin {
  static const double _swipeThreshold = 140;

  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<UserProfile?>? _myProfileSub;
  StreamSubscription<List<UserProfile>>? _discoverSub;

  late final AnimationController _swipeOutController;
  late final AnimationController _snapBackController;
  Animation<Offset>? _swipeOutAnimation;
  Animation<Offset>? _snapBackAnimation;

  int _activeIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _didThresholdHaptic = false;
  bool _swipeLike = false;
  String? _pendingApprovedUid;
  bool _loading = true;
  UserProfile? _myProfile;
  List<UserProfile> _allProfiles = const <UserProfile>[];
  List<UserProfile> _filteredProfiles = const <UserProfile>[];

  RangeValues _edadRango = const RangeValues(20, 40);
  String _filtroGenero = 'Todos';
  bool? _filtroFumador;
  bool? _filtroMascotas;

  int get _activeFiltersCount {
    int count = 0;
    if (_edadRango.start.round() != 20 || _edadRango.end.round() != 40) {
      count += 1;
    }
    if (_filtroGenero != 'Todos') {
      count += 1;
    }
    if (_filtroFumador != null) {
      count += 1;
    }
    if (_filtroMascotas != null) {
      count += 1;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _myProfileSub = _firestoreService.myProfileStream().listen((profile) {
      if (!mounted) {
        return;
      }
      setState(() {
        _myProfile = profile;
        _filteredProfiles = _filtrar(_allProfiles);
        _loading = false;
      });
    });
    _discoverSub = _firestoreService.discoverProfiles().listen((profiles) {
      if (!mounted) {
        return;
      }
      setState(() {
        _allProfiles = profiles;
        _filteredProfiles = _filtrar(_allProfiles);
        _loading = false;
        if (_activeIndex >= _filteredProfiles.length &&
            _filteredProfiles.isNotEmpty) {
          _activeIndex = 0;
        }
      });
    });

    _swipeOutController =
        AnimationController(vsync: this, duration: AppTheme.motionDiscoverSwipe)
          ..addListener(() {
            if (_swipeOutAnimation != null) {
              setState(() => _dragOffset = _swipeOutAnimation!.value);
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              if (_swipeLike && _pendingApprovedUid != null) {
                _firestoreService.ensureThreadWith(_pendingApprovedUid!);
              }
              _swipeOutController.reset();
              _dragOffset = Offset.zero;
              _didThresholdHaptic = false;
              _pendingApprovedUid = null;
              setState(() {
                _activeIndex += 1;
                if (_activeIndex >= _filteredProfiles.length &&
                    _filteredProfiles.isNotEmpty) {
                  _activeIndex = 0;
                }
              });
            }
          });

    _snapBackController =
        AnimationController(vsync: this, duration: AppTheme.motionDiscoverSnap)
          ..addListener(() {
            if (_snapBackAnimation != null) {
              setState(() => _dragOffset = _snapBackAnimation!.value);
            }
          });
  }

  @override
  void dispose() {
    _myProfileSub?.cancel();
    _discoverSub?.cancel();
    _swipeOutController.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  void _animateOut(bool toRight) {
    _swipeLike = toRight;
    final endX = toRight ? 560.0 : -560.0;
    _swipeOutAnimation =
        Tween<Offset>(
          begin: _dragOffset,
          end: Offset(endX, _dragOffset.dy * 1.2),
        ).animate(
          CurvedAnimation(
            parent: _swipeOutController,
            curve: AppTheme.motionCurveEmphasized,
          ),
        );
    _swipeOutController.forward(from: 0);
  }

  void _snapBack() {
    _snapBackAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _snapBackController,
            curve: Curves.elasticOut,
          ),
        );
    _didThresholdHaptic = false;
    _snapBackController.forward(from: 0);
  }

  int _calcAfinidad(UserProfile yo, UserProfile otro) {
    final mine = yo.intereses.toSet();
    final other = otro.intereses.toSet();
    if (mine.isEmpty && other.isEmpty) {
      return 60;
    }
    final comunes = mine.intersection(other).length;
    final union = mine.union(other).length;
    final base = ((comunes / union) * 100).round();

    int bonus = 0;
    if (yo.fumador == otro.fumador) {
      bonus += 10;
    }
    if (yo.mascotas == otro.mascotas) {
      bonus += 10;
    }
    if (yo.horario == otro.horario) {
      bonus += 10;
    }
    final result = (base + bonus).clamp(0, 99);
    return result;
  }

  String _unsplashPortraitByGender(String genero) {
    final normalized = genero.trim().toLowerCase();
    if (normalized.contains('mujer')) {
      return 'https://source.unsplash.com/featured/?young,woman,portrait';
    }
    if (normalized.contains('hombre')) {
      return 'https://source.unsplash.com/featured/?young,man,portrait';
    }
    return 'https://source.unsplash.com/featured/?student,portrait';
  }

  String _unsplashRoomByContext() {
    return 'https://source.unsplash.com/featured/?student,room,apartment';
  }

  List<UserProfile> _filtrar(List<UserProfile> users) {
    final yoTienePiso = _myProfile?.tienePiso == true;
    return users
        .where((u) {
          if (yoTienePiso && u.tienePiso) {
            return false;
          }
          final ageOk =
              u.edad >= _edadRango.start.round() &&
              u.edad <= _edadRango.end.round();
          final generoOk =
              _filtroGenero == 'Todos' || u.genero == _filtroGenero;
          final fumadorOk =
              _filtroFumador == null || u.fumador == _filtroFumador;
          final mascotasOk =
              _filtroMascotas == null || u.mascotas == _filtroMascotas;
          return ageOk && generoOk && fumadorOk && mascotasOk;
        })
        .toList(growable: false);
  }

  Future<void> _abrirFiltros() async {
    RangeValues tempEdad = _edadRango;
    String tempGenero = _filtroGenero;
    bool? tempFumador = _filtroFumador;
    bool? tempMascotas = _filtroMascotas;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBE7E1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Filtros',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Edad: ${tempEdad.start.round()} - ${tempEdad.end.round()} años',
                  ),
                  RangeSlider(
                    values: tempEdad,
                    min: 18,
                    max: 55,
                    activeColor: AppTheme.primary,
                    onChanged: (value) => setModalState(() => tempEdad = value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempGenero,
                    decoration: const InputDecoration(labelText: 'Género'),
                    items: const [
                      DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                      DropdownMenuItem(value: 'Mujer', child: Text('Mujer')),
                      DropdownMenuItem(value: 'Hombre', child: Text('Hombre')),
                      DropdownMenuItem(
                        value: 'No binario',
                        child: Text('No binario'),
                      ),
                    ],
                    onChanged: (value) =>
                        setModalState(() => tempGenero = value ?? 'Todos'),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Fumador: Todos'),
                        selected: tempFumador == null,
                        onSelected: (_) =>
                            setModalState(() => tempFumador = null),
                      ),
                      ChoiceChip(
                        label: const Text('Fumador: Sí'),
                        selected: tempFumador == true,
                        onSelected: (_) =>
                            setModalState(() => tempFumador = true),
                      ),
                      ChoiceChip(
                        label: const Text('Fumador: No'),
                        selected: tempFumador == false,
                        onSelected: (_) =>
                            setModalState(() => tempFumador = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Mascotas: Todos'),
                        selected: tempMascotas == null,
                        onSelected: (_) =>
                            setModalState(() => tempMascotas = null),
                      ),
                      ChoiceChip(
                        label: const Text('Mascotas: Sí'),
                        selected: tempMascotas == true,
                        onSelected: (_) =>
                            setModalState(() => tempMascotas = true),
                      ),
                      ChoiceChip(
                        label: const Text('Mascotas: No'),
                        selected: tempMascotas == false,
                        onSelected: (_) =>
                            setModalState(() => tempMascotas = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _edadRango = tempEdad;
                          _filtroGenero = tempGenero;
                          _filtroFumador = tempFumador;
                          _filtroMascotas = tempMascotas;
                          _filteredProfiles = _filtrar(_allProfiles);
                          _activeIndex = 0;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Aplicar filtros'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final yo = _myProfile;
    final perfiles = _filteredProfiles;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (perfiles.isEmpty || yo == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Text('Descubrir', style: textTheme.headlineMedium),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _abrirFiltros();
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      backgroundColor: const Color(0x2210B981),
                      foregroundColor: AppTheme.primary,
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    label: Text(
                      _activeFiltersCount > 0
                          ? 'Filtros ($_activeFiltersCount)'
                          : 'Filtros',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Perfiles recomendados según tu afinidad',
                  style: textTheme.bodyMedium,
                ),
              ),
              const Spacer(),
              const Text('No hay perfiles que coincidan con tus filtros.'),
              const Spacer(),
            ],
          ),
        ),
      );
    }

    final clampedIndex = _activeIndex % perfiles.length;
    final current = perfiles[clampedIndex];
    final next = perfiles[(clampedIndex + 1) % perfiles.length];
    final third = perfiles[(clampedIndex + 2) % perfiles.length];
    final afinidad = _calcAfinidad(yo, current);

    final dragProgress = (_dragOffset.dx.abs() / _swipeThreshold).clamp(
      0.0,
      1.0,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Text('Descubrir', style: textTheme.headlineMedium),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _abrirFiltros();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    backgroundColor: const Color(0x2210B981),
                    foregroundColor: AppTheme.primary,
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  label: Text(
                    _activeFiltersCount > 0
                        ? 'Filtros ($_activeFiltersCount)'
                        : 'Filtros',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Perfiles recomendados según tu afinidad',
                style: textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _profileCard(
                    third,
                    _calcAfinidad(yo, third),
                    topOffset: 26,
                    scale: 0.9,
                    opacity: 0.35,
                  ),
                  _profileCard(
                    next,
                    _calcAfinidad(yo, next),
                    topOffset: 12,
                    scale: 0.95,
                    opacity: 0.56,
                  ),
                  GestureDetector(
                    onPanStart: (_) {
                      _snapBackController.stop();
                      HapticFeedback.lightImpact();
                    },
                    onPanUpdate: (details) {
                      setState(() => _dragOffset += details.delta);
                      final crossed = _dragOffset.dx.abs() >= _swipeThreshold;
                      if (crossed && !_didThresholdHaptic) {
                        HapticFeedback.mediumImpact();
                        _didThresholdHaptic = true;
                      }
                    },
                    onPanEnd: (details) {
                      final v = details.velocity.pixelsPerSecond.dx;
                      if (_dragOffset.dx > _swipeThreshold || v > 800) {
                        _pendingApprovedUid = current.uid;
                        if (afinidad >= 85) {
                          HapticFeedback.heavyImpact();
                        } else {
                          HapticFeedback.lightImpact();
                        }
                        _animateOut(true);
                      } else if (_dragOffset.dx < -_swipeThreshold ||
                          v < -800) {
                        _pendingApprovedUid = null;
                        HapticFeedback.selectionClick();
                        _animateOut(false);
                      } else {
                        _snapBack();
                      }
                    },
                    child: Transform.translate(
                      offset: _dragOffset,
                      child: Transform.rotate(
                        angle: (_dragOffset.dx / 340) * (math.pi / 14),
                        child: _profileCard(
                          current,
                          afinidad,
                          topOffset: 0,
                          scale: 1,
                          opacity: 1,
                          showApprove: _dragOffset.dx > 8,
                          showReject: _dragOffset.dx < -8,
                          overlayOpacity: dragProgress,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(
                  icon: Icons.close_rounded,
                  color: const Color(0xFFEA5A5A),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _pendingApprovedUid = null;
                    _animateOut(false);
                  },
                ),
                const SizedBox(width: 26),
                _actionButton(
                  icon: _swipeLike
                      ? Icons.home_work_rounded
                      : Icons.check_rounded,
                  color: AppTheme.primary,
                  onTap: () {
                    if (afinidad >= 85) {
                      HapticFeedback.heavyImpact();
                    } else {
                      HapticFeedback.lightImpact();
                    }
                    _pendingApprovedUid = current.uid;
                    _animateOut(true);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140E1E18),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 34),
      ),
    );
  }

  Widget _profileCard(
    UserProfile user,
    int afinidad, {
    required double topOffset,
    required double scale,
    required double opacity,
    bool showApprove = false,
    bool showReject = false,
    double overlayOpacity = 0,
  }) {
    final fallbackImage = user.tienePiso
        ? _unsplashRoomByContext()
        : _unsplashPortraitByGender(user.genero);

    final image = user.fotoPerfil.startsWith('/')
        ? Image.file(
            File(user.fotoPerfil),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: const Color(0xFFE8EFEA)),
          )
        : Image.network(
            user.fotoPerfil.isEmpty ? fallbackImage : user.fotoPerfil,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Image.network(fallbackImage, fit: BoxFit.cover),
          );

    return AnimatedPositioned(
      duration: AppTheme.motionFast,
      curve: AppTheme.motionCurve,
      top: topOffset,
      left: 0,
      right: 0,
      bottom: 0,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x160D1B16),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Column(
                children: [
                  Expanded(
                    flex: 8,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        image,
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.55, 1.0],
                              colors: [Color(0x00000000), Color(0xCC000000)],
                            ),
                          ),
                        ),
                        if (showApprove)
                          _overlayTag(
                            text: 'APROBADO',
                            icon: Icons.home_work_rounded,
                            color: AppTheme.primary,
                            alignLeft: true,
                            opacity: overlayOpacity,
                          ),
                        if (showReject)
                          _overlayTag(
                            text: 'DESCARTAR',
                            icon: Icons.close_rounded,
                            color: const Color(0xFFEA5A5A),
                            alignLeft: false,
                            opacity: overlayOpacity,
                          ),
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 18,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${user.nombre}, ${user.edad}',
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${user.origen} · ${user.horario == 'Manana' ? 'Mañana' : user.horario}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 10),
                              if (user.tienePiso &&
                                  user.precioAlquilerPorPersona != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Text(
                                    '¡Tiene piso! - ${user.precioAlquilerPorPersona!.round()}€/mes',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x1410B981),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '$afinidad% de afinidad',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              minHeight: 10,
                              value: afinidad / 100,
                              backgroundColor: const Color(0xFFE9F2EE),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayTag({
    required String text,
    required IconData icon,
    required Color color,
    required bool alignLeft,
    required double opacity,
  }) {
    return Positioned(
      top: 20,
      left: alignLeft ? 20 : null,
      right: alignLeft ? null : 20,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 2),
            color: Colors.white.withValues(alpha: 0.88),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
