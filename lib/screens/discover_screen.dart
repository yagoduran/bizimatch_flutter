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

  late final AnimationController _swipeOutController;
  Animation<Offset>? _swipeOutAnimation;

  int _activeIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _didThresholdHaptic = false;
  bool _swipeLike = false;
  String? _pendingApprovedUid;

  RangeValues _edadRango = const RangeValues(20, 40);
  String _filtroGenero = 'Todos';
  bool? _filtroFumador;
  bool? _filtroMascotas;

  @override
  void initState() {
    super.initState();
    _swipeOutController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 260),
          )
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
              });
            }
          });
  }

  @override
  void dispose() {
    _swipeOutController.dispose();
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
            curve: Curves.easeOutCubic,
          ),
        );
    _swipeOutController.forward(from: 0);
  }

  void _snapBack() {
    setState(() {
      _dragOffset = Offset.zero;
      _didThresholdHaptic = false;
    });
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

  List<UserProfile> _filtrar(List<UserProfile> users) {
    return users
        .where((u) {
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
                    'Edad: ${tempEdad.start.round()} - ${tempEdad.end.round()} anos',
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
                    value: tempGenero,
                    decoration: const InputDecoration(labelText: 'Genero'),
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
                        label: const Text('Fumador: Si'),
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
                        label: const Text('Mascotas: Si'),
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
    return StreamBuilder<UserProfile?>(
      stream: _firestoreService.myProfileStream(),
      builder: (context, mySnapshot) {
        final yo = mySnapshot.data;

        return StreamBuilder<List<UserProfile>>(
          stream: _firestoreService.discoverProfiles(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final perfiles = _filtrar(snapshot.data ?? const <UserProfile>[]);
            if (perfiles.isEmpty || yo == null) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Descubrir',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _abrirFiltros,
                            icon: const Icon(
                              Icons.tune_rounded,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'No hay perfiles que coincidan con tus filtros.',
                      ),
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
                        const Text(
                          'Descubrir',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _abrirFiltros,
                          icon: const Icon(
                            Icons.tune_rounded,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
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
                            onPanStart: (_) => HapticFeedback.lightImpact(),
                            onPanUpdate: (details) {
                              setState(() => _dragOffset += details.delta);
                              final crossed =
                                  _dragOffset.dx.abs() >= _swipeThreshold;
                              if (crossed && !_didThresholdHaptic) {
                                HapticFeedback.mediumImpact();
                                _didThresholdHaptic = true;
                              }
                            },
                            onPanEnd: (details) {
                              final v = details.velocity.pixelsPerSecond.dx;
                              if (_dragOffset.dx > _swipeThreshold || v > 800) {
                                _pendingApprovedUid = current.uid;
                                _animateOut(true);
                              } else if (_dragOffset.dx < -_swipeThreshold ||
                                  v < -800) {
                                _pendingApprovedUid = null;
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
                            _pendingApprovedUid = null;
                            _animateOut(false);
                          },
                        ),
                        const SizedBox(width: 26),
                        _actionButton(
                          icon: _swipeLike
                              ? Icons.home_rounded
                              : Icons.check_rounded,
                          color: AppTheme.primary,
                          onTap: () {
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
          },
        );
      },
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
    final image = user.fotoPerfil.startsWith('/')
        ? Image.file(
            File(user.fotoPerfil),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: const Color(0xFFE8EFEA)),
          )
        : Image.network(
            user.fotoPerfil.isEmpty
                ? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=700&q=80'
                : user.fotoPerfil,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: const Color(0xFFE8EFEA)),
          );

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      top: topOffset,
      left: 0,
      right: 0,
      bottom: 0,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22000000), Color(0xCC1C2A25)],
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
                        '${user.origen} · ${user.horario}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$afinidad% de afinidad',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: afinidad / 100,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
