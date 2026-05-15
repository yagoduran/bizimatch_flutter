import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/demo_service.dart';
import '../services/firestore_service.dart';
import '../services/imgbb_service.dart';
import '../services/voice_bio_storage_service.dart';
import '../widgets/app_cached_network_image.dart';
import '../widgets/badge_widget.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();
  final VoiceBioStorageService _voiceBioStorage = VoiceBioStorageService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _uploadingProfilePhoto = false;
  bool _uploadingVoiceBio = false;
  bool _isRecordingVoice = false;
  bool _syncingLocalVoiceBio = false;
  int _recordingSeconds = 0;
  String? _lastRecordedPath;
  String? _lastSyncedLocalVoicePath;
  Timer? _recordTimer;
  int? _lastSeenBiziPuntos;
  int? _lastSeenLevel;

  static const List<int> _milestones = <int>[100, 500, 1000, 2500];

  static const List<String> _medallas = <String>[
    'Limpieza',
    'Respeto',
    'Cocina',
    'Silencio',
  ];

  String _emojiMedalla(String tipo) {
    switch (tipo) {
      case 'Limpieza':
        return '🧹';
      case 'Respeto':
        return '🤝';
      case 'Cocina':
        return '🍳';
      case 'Silencio':
        return '🤫';
      default:
        return '🏅';
    }
  }

  Future<void> _abrirBottomSheetResena(UserProfile target) async {
    String medallaSeleccionada = _medallas.first;
    final comentarioCtrl = TextEditingController();
    bool enviando = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dejar reseña a ${target.nombre}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _medallas
                        .map((tipo) {
                          final selected = medallaSeleccionada == tipo;
                          return ChoiceChip(
                            label: Text('${_emojiMedalla(tipo)} $tipo'),
                            selected: selected,
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.14,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppTheme.primary
                                  : const Color(0xFFDCE7E1),
                            ),
                            onSelected: (_) {
                              setModalState(() => medallaSeleccionada = tipo);
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comentarioCtrl,
                    maxLength: 120,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comentario corto',
                      hintText: 'Ej: siempre deja la cocina impecable.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: enviando
                          ? null
                          : () async {
                              final comentario = comentarioCtrl.text.trim();
                              if (comentario.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Escribe un comentario antes de enviar.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => enviando = true);
                              try {
                                await _firestore.dejarResena(
                                  targetUid: target.uid,
                                  texto: comentario,
                                  tipoMedalla: medallaSeleccionada,
                                );
                                if (!mounted) {
                                  return;
                                }
                                Navigator.pop(context);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Reseña enviada a ${target.nombre}.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo enviar la reseña: $e',
                                    ),
                                  ),
                                );
                                setModalState(() => enviando = false);
                              }
                            },
                      child: Text(enviando ? 'Enviando...' : 'Publicar reseña'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    comentarioCtrl.dispose();
  }

  Future<void> _pickProfilePhoto(UserProfile profile) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) {
      return;
    }

    setState(() => _uploadingProfilePhoto = true);

    try {
      final url = await ImgbbService.subirImagen(File(image.path));

      final updated = UserProfile(
        uid: profile.uid,
        email: profile.email,
        nombre: profile.nombre,
        fechaNacimiento: profile.fechaNacimiento,
        genero: profile.genero,
        origen: profile.origen,
        estudios: profile.estudios,
        fumador: profile.fumador,
        mascotas: profile.mascotas,
        tienePiso: profile.tienePiso,
        precioAlquilerPorPersona: profile.precioAlquilerPorPersona,
        horario: profile.horario,
        teletrabajo: profile.teletrabajo,
        frecuenciaFiestas: profile.frecuenciaFiestas,
        nivelLimpieza: profile.nivelLimpieza,
        bio: profile.bio,
        fotoPerfil: url,
        intereses: profile.intereses,
        lugarDeseado: profile.lugarDeseado,
        direccionZona: profile.direccionZona,
        fotosPiso: profile.fotosPiso,
        karma: profile.karma,
        biziPuntos: profile.biziPuntos,
        totalResenas: profile.totalResenas,
        medallasResumen: profile.medallasResumen,
        voiceBioUrl: profile.voiceBioUrl,
      );
      await _firestore.saveUserProfile(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo subir la foto.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingProfilePhoto = false);
      }
    }
  }

  Future<void> _editarPerfil(UserProfile profile) async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: profile.nombre);
    final origenCtrl = TextEditingController(text: profile.origen);
    final estudiosCtrl = TextEditingController(text: profile.estudios);
    final bioCtrl = TextEditingController(text: profile.bio);
    final direccionCtrl = TextEditingController(text: profile.direccionZona);
    final precioCtrl = TextEditingController(
      text: profile.precioAlquilerPorPersona?.toString() ?? '',
    );
    List<String> fotosPiso = List<String>.from(profile.fotosPiso);
    bool uploadingFloorPhotos = false;
    String horario = profile.horario;
    bool teletrabajo = profile.teletrabajo;
    String frecuenciaFiestas = profile.frecuenciaFiestas;
    String nivelLimpieza = profile.nivelLimpieza;
    bool fumador = profile.fumador;
    bool mascotas = profile.mascotas;
    bool tienePiso = profile.tienePiso;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 46,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDE9E3),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Editar perfil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          if (value.length < 3) {
                            return 'Mínimo 3 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: origenCtrl,
                        decoration: const InputDecoration(labelText: 'Origen'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: estudiosCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Qué estudias',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: horario,
                        decoration: const InputDecoration(labelText: 'Horario'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Manana',
                            child: Text('Mañana'),
                          ),
                          DropdownMenuItem(
                            value: 'Tarde',
                            child: Text('Tarde'),
                          ),
                          DropdownMenuItem(
                            value: 'Noche',
                            child: Text('Noche'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => horario = value);
                          }
                        },
                      ),
                      SwitchListTile(
                        value: teletrabajo,
                        activeThumbColor: AppTheme.primary,
                        title: const Text('Teletrabajo'),
                        onChanged: (value) =>
                            setModalState(() => teletrabajo = value),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: frecuenciaFiestas,
                        decoration: const InputDecoration(
                          labelText: 'Frecuencia de fiestas',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                          DropdownMenuItem(
                            value: 'Media',
                            child: Text('Media'),
                          ),
                          DropdownMenuItem(value: 'Baja', child: Text('Baja')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => frecuenciaFiestas = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: nivelLimpieza,
                        decoration: const InputDecoration(
                          labelText: 'Nivel de limpieza',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Estricto',
                            child: Text('Estricto'),
                          ),
                          DropdownMenuItem(
                            value: 'Normal',
                            child: Text('Normal'),
                          ),
                          DropdownMenuItem(
                            value: 'Relajado',
                            child: Text('Relajado'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => nivelLimpieza = value);
                          }
                        },
                      ),
                      SwitchListTile(
                        value: fumador,
                        activeThumbColor: AppTheme.primary,
                        title: const Text('Fumador/a'),
                        onChanged: (value) =>
                            setModalState(() => fumador = value),
                      ),
                      SwitchListTile(
                        value: mascotas,
                        activeThumbColor: AppTheme.primary,
                        title: const Text('Mascotas'),
                        onChanged: (value) =>
                            setModalState(() => mascotas = value),
                      ),
                      SwitchListTile(
                        value: tienePiso,
                        activeThumbColor: AppTheme.primary,
                        title: const Text('Tengo piso ya'),
                        onChanged: (value) {
                          setModalState(() {
                            tienePiso = value;
                            if (!tienePiso) {
                              precioCtrl.clear();
                            }
                          });
                        },
                      ),
                      if (tienePiso) ...[
                        TextFormField(
                          controller: precioCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Precio alquiler por persona (EUR/mes)',
                          ),
                          onChanged: (_) => setModalState(() {}),
                          validator: (value) {
                            if (!tienePiso) {
                              return null;
                            }
                            final text = (value ?? '').trim();
                            if (text.isEmpty) {
                              return 'El precio es obligatorio';
                            }
                            final parsed = double.tryParse(
                              text.replaceAll(',', '.'),
                            );
                            if (parsed == null) {
                              return 'El precio debe ser numérico';
                            }
                            if (parsed <= 0) {
                              return 'El precio debe ser mayor que 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: direccionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Dirección o zona del piso',
                          ),
                          onChanged: (_) => setModalState(() {}),
                          validator: (value) {
                            if (!tienePiso) {
                              return null;
                            }
                            if (value == null || value.trim().isEmpty) {
                              return 'La dirección es obligatoria';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: uploadingFloorPhotos
                              ? null
                              : () async {
                                  final picker = ImagePicker();
                                  final images = await picker.pickMultiImage(
                                    imageQuality: 85,
                                  );
                                  if (images.isEmpty) {
                                    return;
                                  }

                                  setModalState(
                                    () => uploadingFloorPhotos = true,
                                  );

                                  try {
                                    final uploaded = await Future.wait(
                                      images.map(
                                        (e) => ImgbbService.subirImagen(
                                          File(e.path),
                                        ),
                                      ),
                                    );

                                    setModalState(() {
                                      fotosPiso = uploaded;
                                    });
                                  } catch (_) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'No se pudieron subir las fotos del piso.',
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setModalState(
                                        () => uploadingFloorPhotos = false,
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            uploadingFloorPhotos
                                ? 'Subiendo fotos...'
                                : fotosPiso.isEmpty
                                ? 'Subir fotos del piso'
                                : 'Fotos del piso: ${fotosPiso.length}',
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: bioCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Bio'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            bioCtrl.text = _generarBioIA(
                              nombreCtrl.text.trim(),
                              horario,
                              fumador,
                              mascotas,
                            );
                          });
                        },
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Generar Bio con IA'),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          if (tienePiso && fotosPiso.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Debes subir al menos 2 fotos del piso.',
                                ),
                              ),
                            );
                            return;
                          }

                          final confirmar = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: const Text('Confirmar cambios'),
                                content: const Text(
                                  '¿Estás seguro de que quieres actualizar tu perfil?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Aceptar'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirmar != true) {
                            return;
                          }

                          int? precio;
                          if (tienePiso) {
                            precio = double.parse(
                              precioCtrl.text.trim().replaceAll(',', '.'),
                            ).round();
                          }

                          final updated = UserProfile(
                            uid: profile.uid,
                            email: profile.email,
                            nombre: nombreCtrl.text.trim(),
                            fechaNacimiento: profile.fechaNacimiento,
                            genero: profile.genero,
                            origen: origenCtrl.text.trim().isEmpty
                                ? profile.origen
                                : origenCtrl.text.trim(),
                            estudios: estudiosCtrl.text.trim().isEmpty
                                ? profile.estudios
                                : estudiosCtrl.text.trim(),
                            fumador: fumador,
                            mascotas: mascotas,
                            tienePiso: tienePiso,
                            precioAlquilerPorPersona: precio,
                            horario: horario,
                            teletrabajo: teletrabajo,
                            frecuenciaFiestas: frecuenciaFiestas,
                            nivelLimpieza: nivelLimpieza,
                            bio: bioCtrl.text.trim().isEmpty
                                ? profile.bio
                                : bioCtrl.text.trim(),
                            fotoPerfil: profile.fotoPerfil,
                            intereses: profile.intereses,
                            lugarDeseado: profile.lugarDeseado,
                            direccionZona: tienePiso
                                ? direccionCtrl.text.trim()
                                : '',
                            fotosPiso: tienePiso ? fotosPiso : const <String>[],
                            karma: profile.karma,
                            biziPuntos: profile.biziPuntos,
                            totalResenas: profile.totalResenas,
                            medallasResumen: profile.medallasResumen,
                            voiceBioUrl: profile.voiceBioUrl,
                          );

                          await _firestore.saveUserProfile(updated);
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                        },
                        child: const Text('Guardar cambios'),
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

    nombreCtrl.dispose();
    origenCtrl.dispose();
    estudiosCtrl.dispose();
    bioCtrl.dispose();
    direccionCtrl.dispose();
    precioCtrl.dispose();
  }

  String _generarBioIA(
    String nombre,
    String horario,
    bool fumador,
    bool mascotas,
  ) {
    final nombreSeguro = nombre.isEmpty ? 'Esta persona' : nombre;
    final fumadorTxt = fumador ? 'tiene hábito de fumar' : 'no fuma';
    final mascotasTxt = mascotas
        ? 'convive bien con mascotas'
        : 'prefiere ambientes sin mascotas';
    return '$nombreSeguro busca convivencia respetuosa, con comunicación clara y buena organización del piso. Su ritmo principal es de $horario, $fumadorTxt y $mascotasTxt. Le interesa mantener limpieza y acuerdos semanales.';
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _startVoiceRecording(UserProfile profile) async {
    if (_isRecordingVoice || _uploadingVoiceBio) {
      return;
    }

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitas permiso de micrófono para grabar tu bio.'),
        ),
      );
      return;
    }

    final filePath =
        '${Directory.systemTemp.path}/voice_bio_${profile.uid}_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: filePath,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isRecordingVoice = true;
        _recordingSeconds = 0;
        _lastRecordedPath = null;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isRecordingVoice) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingSeconds += 1;
        });
        if (_recordingSeconds >= 15) {
          _stopVoiceRecording(profile, autoStopped: true);
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar la grabación.')),
      );
    }
  }

  Future<void> _stopVoiceRecording(
    UserProfile profile, {
    bool autoStopped = false,
  }) async {
    if (!_isRecordingVoice) {
      return;
    }

    _recordTimer?.cancel();
    final filePath = await _audioRecorder.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _isRecordingVoice = false;
      _uploadingVoiceBio = true;
    });

    if (filePath == null || filePath.trim().isEmpty) {
      setState(() {
        _uploadingVoiceBio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se detectó audio grabado.')),
      );
      return;
    }

    String savedVoiceUrl = filePath;
    bool uploadedToCloud = false;
    try {
      savedVoiceUrl = await _voiceBioStorage.uploadVoiceBio(
        uid: profile.uid,
        localPath: filePath,
      );
      uploadedToCloud = true;

      // Si la subida fue exitosa, borrar temporal local para no acumular archivos.
      await _voiceBioStorage.deleteVoiceBioByPathOrUrl(filePath);

      final previousVoice = (profile.voiceBioUrl ?? '').trim();
      if (previousVoice.isNotEmpty && previousVoice != savedVoiceUrl) {
        try {
          await _voiceBioStorage.deleteVoiceBioByPathOrUrl(previousVoice);
        } catch (_) {
          // Si no se puede borrar el anterior, no bloquear guardado del perfil.
        }
      }
    } catch (_) {
      // Fallback local para no perder la grabación si falla la red/storage.
      savedVoiceUrl = filePath;
    }

    final updated = UserProfile(
      uid: profile.uid,
      email: profile.email,
      nombre: profile.nombre,
      fechaNacimiento: profile.fechaNacimiento,
      genero: profile.genero,
      origen: profile.origen,
      estudios: profile.estudios,
      fumador: profile.fumador,
      mascotas: profile.mascotas,
      tienePiso: profile.tienePiso,
      precioAlquilerPorPersona: profile.precioAlquilerPorPersona,
      horario: profile.horario,
      teletrabajo: profile.teletrabajo,
      frecuenciaFiestas: profile.frecuenciaFiestas,
      nivelLimpieza: profile.nivelLimpieza,
      bio: profile.bio,
      fotoPerfil: profile.fotoPerfil,
      intereses: profile.intereses,
      lugarDeseado: profile.lugarDeseado,
      direccionZona: profile.direccionZona,
      fotosPiso: profile.fotosPiso,
      karma: profile.karma,
      biziPuntos: profile.biziPuntos,
      totalResenas: profile.totalResenas,
      medallasResumen: profile.medallasResumen,
      voiceBioUrl: savedVoiceUrl,
    );
    await _firestore.saveUserProfile(updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _uploadingVoiceBio = false;
      _lastRecordedPath = savedVoiceUrl;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          autoStopped
              ? uploadedToCloud
                    ? 'Grabación subida (límite de 15s alcanzado).'
                    : 'Grabación guardada en local (sin conexión).'
              : uploadedToCloud
              ? 'Nota de voz subida a tu bio.'
              : 'Nota de voz guardada en local (sin conexión).',
        ),
      ),
    );
  }

  Future<void> _deleteVoiceBio(UserProfile profile) async {
    final currentVoice = (profile.voiceBioUrl ?? '').trim();
    if (currentVoice.isEmpty || _uploadingVoiceBio || _isRecordingVoice) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar nota de voz'),
          content: const Text('¿Quieres eliminar tu nota de voz de la bio?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _uploadingVoiceBio = true;
    });

    try {
      await _voiceBioStorage.deleteVoiceBioByPathOrUrl(currentVoice);
    } catch (_) {
      // Aunque falle borrado físico, se limpia referencia del perfil.
    }

    final updated = UserProfile(
      uid: profile.uid,
      email: profile.email,
      nombre: profile.nombre,
      fechaNacimiento: profile.fechaNacimiento,
      genero: profile.genero,
      origen: profile.origen,
      estudios: profile.estudios,
      fumador: profile.fumador,
      mascotas: profile.mascotas,
      tienePiso: profile.tienePiso,
      precioAlquilerPorPersona: profile.precioAlquilerPorPersona,
      horario: profile.horario,
      teletrabajo: profile.teletrabajo,
      frecuenciaFiestas: profile.frecuenciaFiestas,
      nivelLimpieza: profile.nivelLimpieza,
      bio: profile.bio,
      fotoPerfil: profile.fotoPerfil,
      intereses: profile.intereses,
      lugarDeseado: profile.lugarDeseado,
      direccionZona: profile.direccionZona,
      fotosPiso: profile.fotosPiso,
      karma: profile.karma,
      biziPuntos: profile.biziPuntos,
      totalResenas: profile.totalResenas,
      medallasResumen: profile.medallasResumen,
      voiceBioUrl: '',
    );
    await _firestore.saveUserProfile(updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _uploadingVoiceBio = false;
      _lastRecordedPath = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Nota de voz eliminada.')));
  }

  Future<void> _maybeSyncLocalVoiceBio(UserProfile profile) async {
    final voicePath = (profile.voiceBioUrl ?? '').trim();
    final isLocalPath =
        voicePath.startsWith('/') ||
        voicePath.contains(':/') ||
        voicePath.startsWith('\\');

    if (!isLocalPath ||
        _syncingLocalVoiceBio ||
        _uploadingVoiceBio ||
        _isRecordingVoice ||
        voicePath == _lastSyncedLocalVoicePath) {
      return;
    }

    final file = File(voicePath);
    if (!file.existsSync()) {
      _lastSyncedLocalVoicePath = voicePath;
      return;
    }

    _syncingLocalVoiceBio = true;
    _lastSyncedLocalVoicePath = voicePath;
    try {
      final remoteUrl = await _voiceBioStorage.uploadVoiceBio(
        uid: profile.uid,
        localPath: voicePath,
      );

      await _voiceBioStorage.deleteVoiceBioByPathOrUrl(voicePath);

      final updated = UserProfile(
        uid: profile.uid,
        email: profile.email,
        nombre: profile.nombre,
        fechaNacimiento: profile.fechaNacimiento,
        genero: profile.genero,
        origen: profile.origen,
        estudios: profile.estudios,
        fumador: profile.fumador,
        mascotas: profile.mascotas,
        tienePiso: profile.tienePiso,
        precioAlquilerPorPersona: profile.precioAlquilerPorPersona,
        horario: profile.horario,
        teletrabajo: profile.teletrabajo,
        frecuenciaFiestas: profile.frecuenciaFiestas,
        nivelLimpieza: profile.nivelLimpieza,
        bio: profile.bio,
        fotoPerfil: profile.fotoPerfil,
        intereses: profile.intereses,
        lugarDeseado: profile.lugarDeseado,
        direccionZona: profile.direccionZona,
        fotosPiso: profile.fotosPiso,
        karma: profile.karma,
        biziPuntos: profile.biziPuntos,
        totalResenas: profile.totalResenas,
        medallasResumen: profile.medallasResumen,
        voiceBioUrl: remoteUrl,
      );
      await _firestore.saveUserProfile(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu nota de voz local se sincronizó en la nube.'),
            duration: Duration(milliseconds: 1600),
          ),
        );
      }
    } catch (_) {
      // Se mantiene local para reintento manual posterior.
    } finally {
      _syncingLocalVoiceBio = false;
    }
  }

  Widget _voiceBioRecorderSection(UserProfile profile) {
    final seconds = _recordingSeconds.clamp(0, 15);
    final progress = seconds / 15;
    final hasVoiceBio = (profile.voiceBioUrl ?? '').trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EFEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nota de voz en bio',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            _isRecordingVoice
                ? 'Grabando... suelta para guardar (${15 - seconds}s restantes)'
                : 'Mantén pulsado el micrófono para grabar (máx. 15s).',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onLongPressStart: (_) => _startVoiceRecording(profile),
              onLongPressEnd: (_) => _stopVoiceRecording(profile),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _isRecordingVoice ? 86 : 74,
                height: _isRecordingVoice ? 86 : 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecordingVoice
                      ? const Color(0xFF059669)
                      : AppTheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.33),
                      blurRadius: _isRecordingVoice ? 24 : 16,
                      spreadRadius: _isRecordingVoice ? 2 : 0,
                    ),
                  ],
                ),
                child: _uploadingVoiceBio
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: _isRecordingVoice ? progress : 0,
              backgroundColor: const Color(0xFFE8F2EE),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          if (hasVoiceBio || _lastRecordedPath != null)
            Text(
              'Audio listo ${_lastRecordedPath != null ? '(actualizado)' : ''}',
              style: const TextStyle(
                color: Color(0xFF0F9D74),
                fontWeight: FontWeight.w700,
              ),
            ),
          if (hasVoiceBio) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _uploadingVoiceBio
                    ? null
                    : () => _deleteVoiceBio(profile),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Eliminar nota de voz'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB42318),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDemo = DemoService.instance.isDemoMode.value;
    return StreamBuilder<UserProfile?>(
      stream: isDemo
          ? Stream<UserProfile?>.value(
              DemoService.instance.selectedDemoUser.value ??
                  DemoService.instance.demoProfiles.first,
            )
          : _firestore.myProfileStream(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        if (profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final isAssetPath = profile.fotoPerfil.startsWith('assets/');
        final isLocalPath = profile.fotoPerfil.startsWith('/');
        final avatarUrl = profile.fotoPerfil.isEmpty
            ? 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80'
            : profile.fotoPerfil;

        if (!isDemo) {
          _maybeShowPointsToast(profile);
          unawaited(_maybeSyncLocalVoiceBio(profile));
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Perfil',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Gestiona tu información y preferencias',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                _biziLevelHeader(profile),
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      InkWell(
                        onTap: isDemo ? null : () => _pickProfilePhoto(profile),
                        borderRadius: BorderRadius.circular(58),
                        child: Hero(
                          tag: 'photo_${profile.uid}',
                          child: isAssetPath
                              ? CircleAvatar(
                                  radius: 56,
                                  backgroundImage: AssetImage(
                                    profile.fotoPerfil,
                                  ),
                                )
                              : isLocalPath
                              ? CircleAvatar(
                                  radius: 56,
                                  backgroundImage: FileImage(
                                    File(profile.fotoPerfil),
                                  ),
                                )
                              : AppCachedAvatar(
                                  imageUrl: avatarUrl,
                                  radius: 56,
                                ),
                        ),
                      ),
                      if (_uploadingProfilePhoto)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: InkWell(
                          onTap: isDemo ? null : () => _editarPerfil(profile),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_uploadingProfilePhoto) ...[
                  const SizedBox(height: 8),
                  const Center(child: Text('Subiendo foto...')),
                ],
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    profile.nombre,
                    style: textTheme.titleLarge?.copyWith(fontSize: 24),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '${profile.edad} años · ${profile.genero} · ${profile.origen}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 18),
                _section('Sobre mí', profile.bio),
                const SizedBox(height: 12),
                _voiceBioRecorderSection(profile),
                const SizedBox(height: 12),
                _reputationSection(profile),
                const SizedBox(height: 12),
                _coexistenceAchievementsSection(),
                const SizedBox(height: 12),
                _reviewActionsSection(),
                const SizedBox(height: 12),
                _habitsSection(profile),
                const SizedBox(height: 12),
                _section('Estudios', profile.estudios),
                const SizedBox(height: 12),
                _section('Intereses', profile.intereses.join(', ')),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _coexistenceAchievementsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final subtitleColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : const Color(0xFFE8EFEB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Logros de Convivencia',
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 20,
                  color: AppTheme.primary.withValues(alpha: 0.90),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'Insignias que resumen tu estilo dentro del piso.',
              style: TextStyle(color: subtitleColor, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: const [
                BadgeWidget(
                  icon: Icons.cleaning_services_rounded,
                  label: 'Limpio',
                  colors: [Color(0xFF10B981), Color(0xFF22D3EE)],
                ),
                SizedBox(width: 10),
                BadgeWidget(
                  icon: Icons.schedule_rounded,
                  label: 'Puntual en pagos',
                  colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
                ),
                SizedBox(width: 10),
                BadgeWidget(
                  icon: Icons.groups_2_rounded,
                  label: 'Sociable',
                  colors: [Color(0xFFA7F3D0), Color(0xFF10B981)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : const Color(0xFFE8EFEB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _maybeShowPointsToast(UserProfile profile) {
    final current = profile.biziPuntos ?? 0;
    final previous = _lastSeenBiziPuntos;
    final previousLevel = _lastSeenLevel;
    final currentLevel = _levelFromPoints(current);
    _lastSeenBiziPuntos = current;
    _lastSeenLevel = currentLevel;

    if (previousLevel != null && currentLevel > previousLevel && mounted) {
      _showLevelUpOverlay(currentLevel);
    }

    if (previous == null || current <= previous || !mounted) {
      return;
    }

    final delta = current - previous;
    String text;
    if (delta >= 100) {
      text = '+$delta BiziPuntos por conseguir una medalla Karma 🏅';
    } else if (delta >= 50) {
      text = '+$delta BiziPuntos por completar tu bio ✍️';
    } else {
      text = '+$delta BiziPuntos por explorar hoy 🚀';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1600),
          content: Text(text),
        ),
      );
    });
  }

  int _levelFromPoints(int points) {
    const pointsPerLevel = 200;
    return (points ~/ pointsPerLevel) + 1;
  }

  void _showLevelUpOverlay(int level) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'level-up',
      barrierColor: Colors.black.withValues(alpha: 0.34),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, _, _) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE7D48E), width: 1.4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332F3A2E),
                  blurRadius: 26,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFD4AF37),
                  size: 42,
                ),
                const SizedBox(height: 10),
                Text(
                  '¡Subiste a nivel $level!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu perfil gana más visibilidad en vínculos recomendados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _biziLevelHeader(UserProfile profile) {
    final points = profile.biziPuntos ?? 0;
    final streakDays = profile.rachaDias ?? 0;
    final shieldAvailable = profile.comodinRachaDisponible ?? true;
    final perfectWeeks = profile.semanasPerfectas ?? 0;
    const pointsPerLevel = 200;
    final level = _levelFromPoints(points);
    final levelStart = (level - 1) * pointsPerLevel;
    final nextLevelPoints = level * pointsPerLevel;
    final progress = ((points - levelStart) / pointsPerLevel).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFDFF7EC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCDEEDB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Color(0xFF0F9D74)),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Text(
                  'Nivel de Buscador $level',
                  key: ValueKey<int>(level),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: Text(
                  '$points pts',
                  key: ValueKey<int>(points),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F9D74),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: const Color(0xFFCAEBDD),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Siguiente nivel: $nextLevelPoints pts',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _milestones
                .map((target) => _milestoneChip(target: target, points: points))
                .toList(growable: false),
          ),
          if (streakDays > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E8),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFF8D7AE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: Color(0xFFF97316),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Racha diaria: $streakDays día${streakDays == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF9A3412),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: shieldAvailable
                  ? const Color(0xFFEEF6FF)
                  : const Color(0xFFF5F6F7),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: shieldAvailable
                    ? const Color(0xFFBED8FF)
                    : const Color(0xFFE2E8E4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      shieldAvailable
                          ? Icons.shield_moon_rounded
                          : Icons.shield_outlined,
                      size: 16,
                      color: shieldAvailable
                          ? const Color(0xFF2563EB)
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shieldAvailable
                          ? 'Comodín semanal disponible'
                          : 'Comodín semanal usado',
                      style: TextStyle(
                        color: shieldAvailable
                            ? const Color(0xFF1D4ED8)
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (perfectWeeks > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6DB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFF6D98E)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: Color(0xFFB7791F),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Semanas perfectas: $perfectWeeks',
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestoneChip({required int target, required int points}) {
    final reached = points >= target;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: reached ? const Color(0xFFEEF8F3) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: reached ? const Color(0xFFBEE8D1) : const Color(0xFFE2E8E4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            reached ? Icons.verified_rounded : Icons.lock_outline_rounded,
            size: 15,
            color: reached ? const Color(0xFF0F9D74) : AppTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            '$target',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: reached ? const Color(0xFF0F9D74) : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reputationSection(UserProfile profile) {
    return StreamBuilder<List<UserReview>>(
      stream: _firestore.reviewsForUser(profile.uid),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const <UserReview>[];
        final medallas = <String, int>{};
        for (final review in reviews) {
          final tipo = review.tipoMedalla;
          if (tipo.isEmpty) {
            continue;
          }
          medallas[tipo] = (medallas[tipo] ?? 0) + 1;
        }

        final karma = (profile.karma ?? 0).clamp(0, 100).toDouble();
        final totalResenas = profile.totalResenas ?? reviews.length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EFEB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reputación',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Karma ${karma.toStringAsFixed(1)}/100 · $totalResenas reseñas',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: karma / 100,
                  backgroundColor: const Color(0xFFEAF2EE),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (medallas.isEmpty)
                const Text(
                  'Aún no hay medallas. Completa vínculos para recibir reseñas.',
                  style: TextStyle(color: AppTheme.textSecondary),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: medallas.entries
                      .where((entry) => entry.value > 0)
                      .map(
                        (entry) => Chip(
                          label: Text(
                            '${_emojiMedalla(entry.key)} ${entry.key} x${entry.value}',
                          ),
                          backgroundColor: const Color(0xFFF4FAF7),
                          side: const BorderSide(color: Color(0xFFDDE9E3)),
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _reviewActionsSection() {
    return StreamBuilder<List<UserProfile>>(
      stream: _firestore.myMatchedUsersStream(),
      builder: (context, snapshot) {
        final matchedUsers = snapshot.data ?? const <UserProfile>[];
        if (matchedUsers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EFEB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Valorar vínculos',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Si tuviste match, puedes dejar una reseña breve.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              ...matchedUsers
                  .take(4)
                  .map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _abrirBottomSheetResena(user),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                        ),
                        icon: const Icon(Icons.rate_review_outlined, size: 18),
                        label: Text('Dejar reseña a ${user.nombre}'),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _habitsSection(UserProfile profile) {
    final alquiler =
        profile.tienePiso && profile.precioAlquilerPorPersona != null
        ? ' · ${profile.precioAlquilerPorPersona}€/mes'
        : '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EFEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hábitos',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _habitRow(
            '🕒',
            'Horario',
            profile.horario == 'Manana' ? 'Mañana' : profile.horario,
          ),
          const SizedBox(height: 8),
          _habitRow('💻', 'Teletrabajo', profile.teletrabajo ? 'Sí' : 'No'),
          const SizedBox(height: 8),
          _habitRow('🎉', 'Fiestas', profile.frecuenciaFiestas),
          const SizedBox(height: 8),
          _habitRow('🧼', 'Limpieza', profile.nivelLimpieza),
          const SizedBox(height: 8),
          _habitRow(
            profile.fumador ? '🚬' : '🚭',
            'Fumador',
            profile.fumador ? 'Sí' : 'No',
          ),
          const SizedBox(height: 8),
          _habitRow('🐾', 'Mascotas', profile.mascotas ? 'Sí' : 'No'),
          const SizedBox(height: 8),
          _habitRow(
            '🏠',
            'Tiene piso',
            profile.tienePiso ? 'Sí$alquiler' : 'No',
          ),
        ],
      ),
    );
  }

  Widget _habitRow(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }
}
