import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/user_model.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../widgets/app_cached_network_image.dart';

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
  late final AnimationController _loadingShimmerController;
  Animation<Offset>? _swipeOutAnimation;
  Animation<Offset>? _snapBackAnimation;

  int _activeIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _didThresholdHaptic = false;
  bool _swipeLike = false;
  String? _pendingApprovedUid;
  bool _loading = true;
  bool _isLikePressed = false;
  bool _isDislikePressed = false;
  UserProfile? _myProfile;
  List<UserProfile> _allProfiles = const <UserProfile>[];
  List<UserProfile> _filteredProfiles = const <UserProfile>[];

  RangeValues _edadRango = const RangeValues(20, 40);
  String _filtroGenero = 'Todos';
  bool? _filtroFumador;
  bool? _filtroMascotas;
  bool? _filtroTeletrabajo;
  String _filtroFrecuenciaFiestas = 'Todos';
  String _filtroNivelLimpieza = 'Todos';

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
    if (_filtroTeletrabajo != null) {
      count += 1;
    }
    if (_filtroFrecuenciaFiestas != 'Todos') {
      count += 1;
    }
    if (_filtroNivelLimpieza != 'Todos') {
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
      _scheduleNextProfilePrecache();
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
      _scheduleNextProfilePrecache();
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
              // Guardar swipe en interacciones
              if (_pendingApprovedUid != null &&
                  _activeIndex < _filteredProfiles.length) {
                final toUid = _filteredProfiles[_activeIndex].uid;
                final tipo = _swipeLike ? 'like' : 'dislike';
                _guardarSwipeYDetectarMatch(toUid, tipo);
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
              _scheduleNextProfilePrecache();
            }
          });

    _snapBackController =
        AnimationController(vsync: this, duration: AppTheme.motionDiscoverSnap)
          ..addListener(() {
            if (_snapBackAnimation != null) {
              setState(() => _dragOffset = _snapBackAnimation!.value);
            }
          });

    _loadingShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  Future<void> _guardarSwipeYDetectarMatch(String toUid, String tipo) async {
    try {
      final reward = await _firestoreService.guardarSwipe(
        toUid: toUid,
        tipo: tipo,
      );
      if (reward.pointsEarned > 0 && mounted) {
        final text = reward.streakBonusAwarded
            ? '+${reward.pointsEarned} BiziPuntos por racha de ${reward.streakDays} días 🔥'
            : '+${reward.pointsEarned} BiziPuntos por explorar hoy 🚀';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(text),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }

      // Si es like, verificar si hay match
      if (tipo == 'like' && mounted) {
        // Pequeño delay para asegurar que Firestore ha guardado el documento
        await Future.delayed(const Duration(milliseconds: 300));

        final myUid = _myProfile?.uid;
        if (myUid == null) return;

        // Buscar si el otro usuario ya me dio like
        final snapshot = await FirebaseFirestore.instance
            .collection('interacciones')
            .where('fromId', isEqualTo: toUid)
            .where('toId', isEqualTo: myUid)
            .where('tipo', isEqualTo: 'like')
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty && mounted) {
          _mostrarPopupMatch(toUid);
        }
      }
    } catch (e) {
      debugPrint('Error guardando swipe: $e');
    }
  }

  Future<void> _openSafetyActions(UserProfile targetUser) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.block_rounded, color: Colors.red),
                  title: const Text('Bloquear usuario'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _firestoreService.bloquearUsuario(targetUser.uid);
                    if (!mounted) return;
                    _showInfo('Usuario bloqueado correctamente.');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: AppTheme.textPrimary,
                  ),
                  title: const Text('Reportar perfil'),
                  onTap: () async {
                    Navigator.pop(context);
                    final motivo = await _askReportReason();
                    if (motivo == null || motivo.isEmpty) {
                      return;
                    }
                    await _firestoreService.reportarUsuario(
                      reportadoUid: targetUser.uid,
                      motivo: motivo,
                    );
                    if (!mounted) return;
                    _showInfo('Reporte enviado. Gracias por avisar.');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _askReportReason() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reportar perfil'),
          content: const Text('Selecciona un motivo:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'Spam'),
              child: const Text('Spam'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'Fotos falsas'),
              child: const Text('Fotos falsas'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'Ofensivo'),
              child: const Text('Ofensivo'),
            ),
          ],
        );
      },
    );
  }

  void _showInfo(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _mostrarPopupMatch(String otroUid) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'match-celebration',
      barrierColor: Colors.black.withValues(alpha: 0.54),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (dialogContext, _, _) {
        return _MatchCelebrationOverlay(
          onClose: () => Navigator.pop(dialogContext),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _setLikePressed(bool value) {
    if (_isLikePressed == value || !mounted) {
      return;
    }
    setState(() => _isLikePressed = value);
  }

  void _setDislikePressed(bool value) {
    if (_isDislikePressed == value || !mounted) {
      return;
    }
    setState(() => _isDislikePressed = value);
  }

  @override
  void dispose() {
    _myProfileSub?.cancel();
    _discoverSub?.cancel();
    _swipeOutController.dispose();
    _snapBackController.dispose();
    _loadingShimmerController.dispose();
    super.dispose();
  }

  void _scheduleNextProfilePrecache() {
    if (_filteredProfiles.length < 2) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _filteredProfiles.length < 2) {
        return;
      }

      final nextIndex = (_activeIndex + 1) % _filteredProfiles.length;
      final nextProfile = _filteredProfiles[nextIndex];
      precacheImage(_profileImageProvider(nextProfile), context);
    });
  }

  ImageProvider<Object> _profileImageProvider(UserProfile user) {
    if (user.fotoPerfil.startsWith('/')) {
      return FileImage(File(user.fotoPerfil));
    }

    final fallbackImage = user.tienePiso
        ? _unsplashRoomByContext()
        : _unsplashPortraitByGender(user.genero);

    return CachedNetworkImageProvider(
      user.fotoPerfil.isEmpty ? fallbackImage : user.fotoPerfil,
      maxWidth: 500,
    );
  }

  Key _profileCardKey(UserProfile user, String slot) {
    final id = user.uid.trim();
    if (id.isEmpty) {
      return UniqueKey();
    }
    return ValueKey<String>('$slot:$id');
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

  UserModel _toUserModel(UserProfile profile) {
    return UserModel(
      id: profile.uid,
      nombre: profile.nombre,
      email: profile.email,
      fotoPerfil: profile.fotoPerfil,
      fechaNacimiento: profile.fechaNacimiento,
      genero: profile.genero,
      origen: profile.origen,
      estudios: profile.estudios,
      esFumador: profile.fumador,
      tieneMascotas: profile.mascotas,
      tienePiso: profile.tienePiso,
      precioAlquilerPorPersona: profile.precioAlquilerPorPersona?.toDouble(),
      horario: profile.horario,
      teletrabajo: profile.teletrabajo,
      frecuenciaFiestas: profile.frecuenciaFiestas,
      nivelLimpieza: profile.nivelLimpieza,
      bio: profile.bio,
      lugarDeseado: profile.lugarDeseado,
      karma: profile.karma ?? 0,
      biziPuntos: profile.biziPuntos ?? 0,
    );
  }

  int calcularAfinidad(UserModel miUsuario, UserModel otroUsuario) {
    int score = 20;
    final horarioA = miUsuario.horario.trim().toLowerCase().replaceAll(
      'ñ',
      'n',
    );
    final horarioB = otroUsuario.horario.trim().toLowerCase().replaceAll(
      'ñ',
      'n',
    );

    if (miUsuario.esFumador == otroUsuario.esFumador) {
      score += 10;
    }
    if (miUsuario.tieneMascotas == otroUsuario.tieneMascotas) {
      score += 10;
    }
    if (horarioA == horarioB) {
      score += 10;
    }
    if (miUsuario.frecuenciaFiestas == otroUsuario.frecuenciaFiestas) {
      score += 12;
    }
    if (miUsuario.nivelLimpieza == otroUsuario.nivelLimpieza) {
      score += 13;
    }
    if ((miUsuario.edad - otroUsuario.edad).abs() < 5) {
      score += 10;
    }

    if (miUsuario.teletrabajo == otroUsuario.teletrabajo &&
        horarioA == horarioB) {
      score += 35;
    }

    final choqueCritico =
        (miUsuario.frecuenciaFiestas == 'Alta' &&
            otroUsuario.nivelLimpieza == 'Estricto') ||
        (otroUsuario.frecuenciaFiestas == 'Alta' &&
            miUsuario.nivelLimpieza == 'Estricto');
    if (choqueCritico) {
      score -= 40;
    }

    return score.clamp(0, 100);
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
          final teletrabajoOk =
              _filtroTeletrabajo == null || u.teletrabajo == _filtroTeletrabajo;
          final fiestasOk =
              _filtroFrecuenciaFiestas == 'Todos' ||
              u.frecuenciaFiestas == _filtroFrecuenciaFiestas;
          final limpiezaOk =
              _filtroNivelLimpieza == 'Todos' ||
              u.nivelLimpieza == _filtroNivelLimpieza;
          return ageOk &&
              generoOk &&
              fumadorOk &&
              mascotasOk &&
              teletrabajoOk &&
              fiestasOk &&
              limpiezaOk;
        })
        .toList(growable: false);
  }

  Future<void> _abrirFiltros() async {
    RangeValues tempEdad = _edadRango;
    String tempGenero = _filtroGenero;
    bool? tempFumador = _filtroFumador;
    bool? tempMascotas = _filtroMascotas;
    bool? tempTeletrabajo = _filtroTeletrabajo;
    String tempFrecuenciaFiestas = _filtroFrecuenciaFiestas;
    String tempNivelLimpieza = _filtroNivelLimpieza;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 14,
                    bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 46,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8E5DE),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Filtros',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempEdad = const RangeValues(20, 40);
                                tempGenero = 'Todos';
                                tempFumador = null;
                                tempMascotas = null;
                                tempTeletrabajo = null;
                                tempFrecuenciaFiestas = 'Todos';
                                tempNivelLimpieza = 'Todos';
                              });
                            },
                            child: const Text('Reiniciar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FBF9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE3EEE8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Edad',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                _filterPill('${tempEdad.start.round()} años'),
                                const SizedBox(width: 8),
                                _filterPill('${tempEdad.end.round()} años'),
                              ],
                            ),
                            RangeSlider(
                              values: tempEdad,
                              min: 18,
                              max: 55,
                              labels: RangeLabels(
                                '${tempEdad.start.round()}',
                                '${tempEdad.end.round()}',
                              ),
                              activeColor: AppTheme.primary,
                              inactiveColor: const Color(0xFFDCE7E1),
                              onChanged: (value) =>
                                  setModalState(() => tempEdad = value),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '18',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '55',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Género',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected: tempGenero == 'Todos',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempGenero == 'Todos'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempGenero == 'Todos'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) =>
                                setModalState(() => tempGenero = 'Todos'),
                          ),
                          ChoiceChip(
                            label: const Text('Mujer'),
                            selected: tempGenero == 'Mujer',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempGenero == 'Mujer'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempGenero == 'Mujer'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) =>
                                setModalState(() => tempGenero = 'Mujer'),
                          ),
                          ChoiceChip(
                            label: const Text('Hombre'),
                            selected: tempGenero == 'Hombre',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempGenero == 'Hombre'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempGenero == 'Hombre'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) =>
                                setModalState(() => tempGenero = 'Hombre'),
                          ),
                          ChoiceChip(
                            label: const Text('No binario'),
                            selected: tempGenero == 'No binario',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempGenero == 'No binario'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempGenero == 'No binario'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) =>
                                setModalState(() => tempGenero = 'No binario'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _segmentedFilterGroup(
                        title: 'Fumador',
                        value: tempFumador,
                        onChanged: (value) =>
                            setModalState(() => tempFumador = value),
                      ),
                      const SizedBox(height: 18),
                      _segmentedFilterGroup(
                        title: 'Mascotas',
                        value: tempMascotas,
                        onChanged: (value) =>
                            setModalState(() => tempMascotas = value),
                      ),
                      const SizedBox(height: 18),
                      _segmentedFilterGroup(
                        title: 'Teletrabajo',
                        value: tempTeletrabajo,
                        onChanged: (value) =>
                            setModalState(() => tempTeletrabajo = value),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Frecuencia de fiestas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected: tempFrecuenciaFiestas == 'Todos',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempFrecuenciaFiestas == 'Todos'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempFrecuenciaFiestas == 'Todos'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) => setModalState(
                              () => tempFrecuenciaFiestas = 'Todos',
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Alta'),
                            selected: tempFrecuenciaFiestas == 'Alta',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempFrecuenciaFiestas == 'Alta'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempFrecuenciaFiestas == 'Alta'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) => setModalState(
                              () => tempFrecuenciaFiestas = 'Alta',
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Media'),
                            selected: tempFrecuenciaFiestas == 'Media',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempFrecuenciaFiestas == 'Media'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempFrecuenciaFiestas == 'Media'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) => setModalState(
                              () => tempFrecuenciaFiestas = 'Media',
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Baja'),
                            selected: tempFrecuenciaFiestas == 'Baja',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempFrecuenciaFiestas == 'Baja'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempFrecuenciaFiestas == 'Baja'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) => setModalState(
                              () => tempFrecuenciaFiestas = 'Baja',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Nivel de limpieza',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected: tempNivelLimpieza == 'Todos',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempNivelLimpieza == 'Todos'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempNivelLimpieza == 'Todos'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) => setModalState(
                              () => tempNivelLimpieza = 'Todos',
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Estricto'),
                            selected: tempNivelLimpieza == 'Estricto',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempNivelLimpieza == 'Estricto'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempNivelLimpieza == 'Estricto'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) => setModalState(
                              () => tempNivelLimpieza = 'Estricto',
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Normal'),
                            selected: tempNivelLimpieza == 'Normal',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempNivelLimpieza == 'Normal'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempNivelLimpieza == 'Normal'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) => setModalState(
                              () => tempNivelLimpieza = 'Normal',
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Relajado'),
                            selected: tempNivelLimpieza == 'Relajado',
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                            backgroundColor: const Color(0xFFF6FAF8),
                            labelStyle: TextStyle(
                              color: tempNivelLimpieza == 'Relajado'
                                  ? AppTheme.primary
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: tempNivelLimpieza == 'Relajado'
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) => setModalState(
                              () => tempNivelLimpieza = 'Relajado',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _edadRango = tempEdad;
                              _filtroGenero = tempGenero;
                              _filtroFumador = tempFumador;
                              _filtroMascotas = tempMascotas;
                              _filtroTeletrabajo = tempTeletrabajo;
                              _filtroFrecuenciaFiestas = tempFrecuenciaFiestas;
                              _filtroNivelLimpieza = tempNivelLimpieza;
                              _filteredProfiles = _filtrar(_allProfiles);
                              _activeIndex = 0;
                            });
                            _scheduleNextProfilePrecache();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Aplicar filtros',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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

    if (yo == null) {
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
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    if (perfiles.isEmpty) {
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
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 96,
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.85),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '¡No hay más Vínculos en tu zona!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Intenta ampliar tus filtros o vuelve más tarde.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _abrirFiltros();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Revisar Filtros'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final clampedIndex = _activeIndex % perfiles.length;
    final current = perfiles[clampedIndex];
    final next = perfiles[(clampedIndex + 1) % perfiles.length];
    final third = perfiles[(clampedIndex + 2) % perfiles.length];
    final miUsuario = _toUserModel(yo);
    final afinidad = calcularAfinidad(miUsuario, _toUserModel(current));

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
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _openSafetyActions(current);
                  },
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'Más opciones',
                ),
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
                    calcularAfinidad(miUsuario, _toUserModel(third)),
                    topOffset: 26,
                    scale: 0.9,
                    opacity: 0.35,
                    key: _profileCardKey(third, 'third'),
                  ),
                  _profileCard(
                    next,
                    calcularAfinidad(miUsuario, _toUserModel(next)),
                    topOffset: 12,
                    scale: 0.95,
                    opacity: 0.56,
                    key: _profileCardKey(next, 'next'),
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
                          key: _profileCardKey(current, 'current'),
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
                  isPressed: _isDislikePressed,
                  onPressChanged: _setDislikePressed,
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
                  isPressed: _isLikePressed,
                  onPressChanged: _setLikePressed,
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
    required bool isPressed,
    required ValueChanged<bool> onPressChanged,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTapDown: (_) => onPressChanged(true),
      onTapUp: (_) => onPressChanged(false),
      onTapCancel: () => onPressChanged(false),
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        width: isPressed ? 66 : 72,
        height: isPressed ? 66 : 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: color.withValues(alpha: isPressed ? 0.62 : 0.4),
            width: isPressed ? 1.8 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x140E1E18),
              blurRadius: isPressed ? 10 : 18,
              offset: Offset(0, isPressed ? 4 : 8),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: isPressed ? 31 : 34),
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
    required Key key,
  }) {
    final isExceptionalAffinity = afinidad > 90;
    final affinityColor = isExceptionalAffinity
        ? const Color(0xFFD4AF37)
        : afinidad > 50
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    final fallbackImage = user.tienePiso
        ? _unsplashRoomByContext()
        : _unsplashPortraitByGender(user.genero);

    final image = user.fotoPerfil.startsWith('/')
        ? Image.file(
            File(user.fotoPerfil),
            fit: BoxFit.cover,
            cacheHeight: 800,
            cacheWidth: 400,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return _loadingImagePlaceholder();
            },
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFFF1F6F4),
              child: _loadingImagePlaceholder(
                icon: Icons.image_not_supported_outlined,
                label: 'Imagen no disponible',
              ),
            ),
          )
        : AppCachedNetworkImage(
            imageUrl: user.fotoPerfil.isEmpty ? fallbackImage : user.fotoPerfil,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: 500,
          );

    return AnimatedPositioned(
      key: key,
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
                              color: affinityColor.withValues(
                                alpha: isExceptionalAffinity ? 0.22 : 0.15,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: isExceptionalAffinity
                                  ? Border.all(
                                      color: const Color(0xFFE2C15B),
                                      width: 1.1,
                                    )
                                  : null,
                              boxShadow: isExceptionalAffinity
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x80D4AF37),
                                        blurRadius: 14,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              '$afinidad% de afinidad',
                              style: TextStyle(
                                color: affinityColor,
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

  Widget _filterPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE7E1)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4E645A),
        ),
      ),
    );
  }

  Widget _segmentedFilterGroup({
    required String title,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    final selectedColor = AppTheme.primary.withValues(alpha: 0.14);
    final normalBorder = const Color(0xFFDCE7E1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FBF9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: normalBorder),
          ),
          child: ToggleButtons(
            isSelected: [value == null, value == true, value == false],
            onPressed: (index) {
              switch (index) {
                case 0:
                  onChanged(null);
                  break;
                case 1:
                  onChanged(true);
                  break;
                case 2:
                  onChanged(false);
                  break;
              }
            },
            borderRadius: BorderRadius.circular(14),
            fillColor: selectedColor,
            selectedColor: AppTheme.primary,
            color: const Color(0xFF5C6E67),
            constraints: const BoxConstraints(minHeight: 44),
            borderColor: Colors.transparent,
            selectedBorderColor: Colors.transparent,
            splashColor: AppTheme.primary.withValues(alpha: 0.08),
            renderBorder: false,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Todos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Sí',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'No',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loadingImagePlaceholder({
    IconData icon = Icons.image_outlined,
    String label = 'Cargando perfil',
  }) {
    return AnimatedBuilder(
      animation: _loadingShimmerController,
      builder: (context, child) {
        final shimmer = _loadingShimmerController.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.2 + shimmer * 2.4, -0.9),
              end: Alignment(1.2 + shimmer * 2.4, 0.9),
              colors: const [
                Color(0xFFF2F6F4),
                Color(0xFFE3ECE7),
                Color(0xFFF7FAF8),
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.36),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 34, color: const Color(0xFF8FA59A)),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6E8179),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MatchCelebrationOverlay extends StatefulWidget {
  const _MatchCelebrationOverlay({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_MatchCelebrationOverlay> createState() =>
      _MatchCelebrationOverlayState();
}

class _MatchCelebrationOverlayState extends State<_MatchCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _textController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 2400),
    )..play();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.34)),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              emissionFrequency: 0.035,
              numberOfParticles: 28,
              gravity: 0.2,
              colors: const [
                Color(0xFF10B981),
                Color(0xFFF59E0B),
                Color(0xFF22C55E),
                Colors.white,
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -math.pi / 2,
              shouldLoop: false,
              emissionFrequency: 0.025,
              numberOfParticles: 22,
              gravity: 0.24,
              colors: const [
                Color(0xFF10B981),
                Color(0xFF34D399),
                Color(0xFFFDE68A),
                Colors.white,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: Tween<double>(begin: 0.72, end: 1).animate(pulse),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1.08).animate(pulse),
                    child: const Text(
                      '¡Es un Vínculo!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 42,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Color(0x88000000),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Like mutuo detectado. Ya podéis hablar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: widget.onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Seguir',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
