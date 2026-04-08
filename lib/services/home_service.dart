import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/casa_model.dart';
import '../models/tarea_model.dart';

/// Servicio para gestionar casas, tareas y puntos gamificados
class HomeService {
  HomeService._privateConstructor();
  static final HomeService _instance = HomeService._privateConstructor();
  static HomeService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Crea una nueva casa (se llama al confirmar mudanza)
  Future<String> crearCasa({
    required List<String> miembrosIds,
    String? nombreCasa,
    String? ubicacion,
  }) async {
    try {
      final docRef = _firestore.collection('casas').doc();
      final idCasa = docRef.id;

      final casa = Casa(
        idCasa: idCasa,
        miembrosIds: miembrosIds,
        fechaCreacion: DateTime.now(),
        nombreCasa: nombreCasa,
        ubicacion: ubicacion,
        estaActiva: true,
      );

      await docRef.set(casa.toMap());

      // Actualizar perfil de cada miembro con id_casa
      for (final uid in miembrosIds) {
        await _firestore.collection('usuarios').doc(uid).update({
          'id_casa': idCasa,
        });
      }

      return idCasa;
    } catch (e) {
      print('Error creando casa: $e');
      rethrow;
    }
  }

  /// Obtiene una casa por ID
  Future<Casa?> obtenerCasa(String idCasa) async {
    try {
      final doc = await _firestore.collection('casas').doc(idCasa).get();
      if (!doc.exists) return null;
      return Casa.fromFirestore(doc.data() ?? {}, id: idCasa);
    } catch (e) {
      print('Error obteniendo casa: $e');
      return null;
    }
  }

  /// Stream en tiempo real de una casa
  Stream<Casa?> getCasaStream(String idCasa) {
    return _firestore.collection('casas').doc(idCasa).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Casa.fromFirestore(doc.data() ?? {}, id: idCasa);
    });
  }

  /// Crea una nueva tarea
  Future<String> crearTarea({
    required String idCasa,
    required String titulo,
    required int puntos,
    required String asignadoA,
    required DateTime fechaLimite,
    String? descripcion,
    required TareaCategoria categoria,
    bool recurrente = false,
  }) async {
    try {
      final docRef = _firestore
          .collection('casas')
          .doc(idCasa)
          .collection('tareas')
          .doc();
      final idTarea = docRef.id;

      final tarea = Tarea(
        idTarea: idTarea,
        idCasa: idCasa,
        titulo: titulo,
        descripcion: descripcion,
        puntos: puntos,
        asignadoA: asignadoA,
        completada: false,
        fechaLimite: fechaLimite,
        categoria: categoria,
        recurrente: recurrente,
      );

      await docRef.set(tarea.toMap());
      return idTarea;
    } catch (e) {
      print('Error creando tarea: $e');
      rethrow;
    }
  }

  /// Obtiene todas las tareas de una casa
  Future<List<Tarea>> obtenerTareas(String idCasa) async {
    try {
      final snapshot = await _firestore
          .collection('casas')
          .doc(idCasa)
          .collection('tareas')
          .orderBy('fecha_limite')
          .get();

      return snapshot.docs
          .map((doc) => Tarea.fromFirestore(doc.data(), id: doc.id))
          .toList();
    } catch (e) {
      print('Error obteniendo tareas: $e');
      return [];
    }
  }

  /// Stream en tiempo real de tareas
  Stream<List<Tarea>> getTareasStream(String idCasa) {
    return _firestore
        .collection('casas')
        .doc(idCasa)
        .collection('tareas')
        .orderBy('fecha_limite')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Tarea.fromFirestore(doc.data(), id: doc.id))
              .toList();
        });
  }

  /// Marca una tarea como completada y suma puntos
  Future<void> completarTarea({
    required String idCasa,
    required String idTarea,
    required String uidUsuario,
    required int puntos,
  }) async {
    try {
      // Actualizar tarea
      await _firestore
          .collection('casas')
          .doc(idCasa)
          .collection('tareas')
          .doc(idTarea)
          .update({'completada': true, 'fecha_completada': Timestamp.now()});

      // Sumar puntos al usuario (BiziPuntos del mes actual)
      await _firestore.collection('usuarios').doc(uidUsuario).update({
        'biziPuntos': FieldValue.increment(puntos),
      });

      // También guardar en un subcollection de "historial de puntos" del mes actual
      final ahora = DateTime.now();
      final mesActual =
          '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';

      await _firestore
          .collection('usuarios')
          .doc(uidUsuario)
          .collection('puntos_mensuales')
          .doc(mesActual)
          .update({
            'puntos': FieldValue.increment(puntos),
            'actualizado_en': Timestamp.now(),
          })
          .catchError((e) async {
            // Si el documento no existe, crarlo
            if (e.code == 'NOT_FOUND' || e.toString().contains('NotFound')) {
              await _firestore
                  .collection('usuarios')
                  .doc(uidUsuario)
                  .collection('puntos_mensuales')
                  .doc(mesActual)
                  .set({
                    'puntos': puntos,
                    'mes': mesActual,
                    'estado_mes': 'activo',
                    'creado_en': Timestamp.now(),
                    'actualizado_en': Timestamp.now(),
                  });
            }
          });
    } catch (e) {
      print('Error completando tarea: $e');
      rethrow;
    }
  }

  /// Obtiene puntos del mes actual de todos los miembros de una casa
  Future<Map<String, int>> obtenerPuntosDelMes(String idCasa) async {
    try {
      final casa = await obtenerCasa(idCasa);
      if (casa == null) return {};

      final puntosMap = <String, int>{};
      final ahora = DateTime.now();
      final mesActual =
          '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';

      for (final uid in casa.miembrosIds) {
        try {
          final doc = await _firestore
              .collection('usuarios')
              .doc(uid)
              .collection('puntos_mensuales')
              .doc(mesActual)
              .get();

          if (doc.exists) {
            puntosMap[uid] = doc['puntos'] as int? ?? 0;
          } else {
            puntosMap[uid] = 0;
          }
        } catch (e) {
          puntosMap[uid] = 0;
        }
      }

      return puntosMap;
    } catch (e) {
      print('Error obteniendo puntos del mes: $e');
      return {};
    }
  }

  /// Stream de puntos del mes actual
  Stream<Map<String, int>> getPuntosDelMesStream(String idCasa) async* {
    try {
      final casa = await obtenerCasa(idCasa);
      if (casa == null) {
        yield {};
        return;
      }

      final ahora = DateTime.now();
      final mesActual =
          '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';

      // Combinar streams de puntos de todos los miembros
      final streams = casa.miembrosIds.map((uid) {
        return _firestore
            .collection('usuarios')
            .doc(uid)
            .collection('puntos_mensuales')
            .doc(mesActual)
            .snapshots()
            .map((doc) {
              return (uid, doc['puntos'] as int? ?? 0);
            });
      }).toList();

      if (streams.isEmpty) {
        yield {};
        return;
      }

      // Combinar todos los streams
      final combinedStream = _combineStreams(streams);
      await for (final puntosData in combinedStream) {
        final puntosMap = <String, int>{};
        for (final (uid, puntos) in puntosData) {
          puntosMap[uid] = puntos;
        }
        yield puntosMap;
      }
    } catch (e) {
      print('Error en stream de puntos: $e');
      yield {};
    }
  }

  /// Elimina una tarea
  Future<void> eliminarTarea(String idCasa, String idTarea) async {
    try {
      await _firestore
          .collection('casas')
          .doc(idCasa)
          .collection('tareas')
          .doc(idTarea)
          .delete();
    } catch (e) {
      print('Error eliminando tarea: $e');
      rethrow;
    }
  }

  /// Obtiene el líder del mes (compañero con más puntos)
  Future<String?> obtenerLiderDelMes(String idCasa) async {
    try {
      final puntos = await obtenerPuntosDelMes(idCasa);
      if (puntos.isEmpty) return null;

      String lider = puntos.keys.first;
      int maxPuntos = puntos[lider] ?? 0;

      for (final entry in puntos.entries) {
        if (entry.value > maxPuntos) {
          lider = entry.key;
          maxPuntos = entry.value;
        }
      }

      return lider;
    } catch (e) {
      print('Error obteniendo líder del mes: $e');
      return null;
    }
  }

  /// Helper para combinar múltiples streams
  Stream<List<(String, int)>> _combineStreams(
    List<Stream<(String, int)>> streams,
  ) async* {
    final subscriptions = <StreamSubscription<(String, int)>>[];
    final values = <String, int>{};

    try {
      final allDone = Future.wait(
        streams.map((stream) async {
          final sub = stream.listen((value) {
            values[value.$1] = value.$2;
          });
          subscriptions.add(sub);
        }),
      );

      // Yield initial values
      yield values.entries.map((e) => (e.key, e.value)).toList();

      await allDone;

      // Keep yielding updates
      while (true) {
        await Future.delayed(Duration(milliseconds: 100));
        yield values.entries.map((e) => (e.key, e.value)).toList();
      }
    } finally {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    }
  }
}
