import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/escuadron_model.dart';

class EscuadronService {
  static final EscuadronService instance = EscuadronService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  EscuadronService._internal();

  /// Crea un nuevo escuadrón con dos miembros iniciales
  Future<Escuadron> crearEscuadron(
    List<String> miembrosIds, {
    double? precioMaximo,
    String? zona,
  }) async {
    try {
      final docRef = _firestore.collection('escuadrones').doc();
      final escuadron = Escuadron.empty(docRef.id, miembrosIds);
      final escuadronConPrefs = escuadron.actualizarPreferencias(
        PreferenciasComunes(precioMaximo: precioMaximo, zona: zona),
      );

      await docRef.set(escuadronConPrefs.toMap());

      // Actualizar los usuarios con su id_escuadron
      for (final uid in miembrosIds) {
        await _firestore.collection('usuarios').doc(uid).update({
          'idEscuadronActual': docRef.id,
        });
      }

      return escuadronConPrefs;
    } catch (e) {
      print('Error al crear escuadrón: $e');
      rethrow;
    }
  }

  /// Obtiene un escuadrón por ID
  Future<Escuadron?> obtenerEscuadron(String escuadronId) async {
    try {
      final doc = await _firestore
          .collection('escuadrones')
          .doc(escuadronId)
          .get();
      if (doc.exists) {
        return Escuadron.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error al obtener escuadrón: $e');
      return null;
    }
  }

  /// Stream en tiempo real de un escuadrón
  Stream<Escuadron?> getEscuadronStream(String escuadronId) {
    return _firestore
        .collection('escuadrones')
        .doc(escuadronId)
        .snapshots()
        .map((doc) => doc.exists ? Escuadron.fromFirestore(doc) : null);
  }

  /// Añade un miembro al escuadrón
  Future<void> anadirMiembro(String escuadronId, String nuevoUid) async {
    try {
      final escuadron = await obtenerEscuadron(escuadronId);
      if (escuadron != null &&
          escuadron.puedeAnadirMiembro &&
          !escuadron.listaMiembrosIds.contains(nuevoUid)) {
        final escuadronActualizado = escuadron.anadirMiembro(nuevoUid);

        await _firestore.collection('escuadrones').doc(escuadronId).update({
          'listaMiembrosIds': escuadronActualizado.listaMiembrosIds,
        });

        // Actualizar el usuario
        await _firestore.collection('usuarios').doc(nuevoUid).update({
          'idEscuadronActual': escuadronId,
        });
      }
    } catch (e) {
      print('Error al añadir miembro: $e');
    }
  }

  /// Remueve un miembro del escuadrón
  Future<void> removerMiembro(String escuadronId, String uidARemover) async {
    try {
      final escuadron = await obtenerEscuadron(escuadronId);
      if (escuadron != null) {
        final escuadronActualizado = escuadron.removerMiembro(uidARemover);

        if (escuadronActualizado.listaMiembrosIds.isEmpty) {
          // Si no hay miembros, disolver el escuadrón
          await disolverEscuadron(escuadronId);
        } else {
          await _firestore.collection('escuadrones').doc(escuadronId).update({
            'listaMiembrosIds': escuadronActualizado.listaMiembrosIds,
          });
        }

        // Limpiar el usuario
        await _firestore.collection('usuarios').doc(uidARemover).update({
          'idEscuadronActual': FieldValue.delete(),
        });
      }
    } catch (e) {
      print('Error al remover miembro: $e');
    }
  }

  /// Actualiza preferencias comunes del escuadrón
  Future<void> actualizarPreferencias(
    String escuadronId,
    double? precioMaximo,
    String? zona,
  ) async {
    try {
      await _firestore.collection('escuadrones').doc(escuadronId).update({
        'preferenciasComunas': PreferenciasComunes(
          precioMaximo: precioMaximo,
          zona: zona,
        ).toMap(),
      });
    } catch (e) {
      print('Error al actualizar preferencias: $e');
    }
  }

  /// Disuelve un escuadrón completamente
  Future<void> disolverEscuadron(String escuadronId) async {
    try {
      final escuadron = await obtenerEscuadron(escuadronId);
      if (escuadron != null) {
        // Limpiar IDs en todos los miembros
        for (final uid in escuadron.listaMiembrosIds) {
          await _firestore.collection('usuarios').doc(uid).update({
            'idEscuadronActual': FieldValue.delete(),
          });
        }

        // Desactivar el escuadrón
        await _firestore.collection('escuadrones').doc(escuadronId).update({
          'estaActivo': false,
          'listaMiembrosIds': [],
        });
      }
    } catch (e) {
      print('Error al disolver escuadrón: $e');
    }
  }

  /// Obtiene el escuadrón actual del usuario
  Future<Escuadron?> obtenerEscuadronActual(String uid) async {
    try {
      final userDoc = await _firestore.collection('usuarios').doc(uid).get();
      final escuadronId = userDoc.data()?['idEscuadronActual'] as String?;

      if (escuadronId != null) {
        return await obtenerEscuadron(escuadronId);
      }
      return null;
    } catch (e) {
      print('Error al obtener escuadrón actual: $e');
      return null;
    }
  }

  /// Stream del escuadrón actual del usuario
  Stream<Escuadron?> getEscuadronActualStream(String uid) {
    return _firestore.collection('usuarios').doc(uid).snapshots().asyncExpand((
      userDoc,
    ) {
      final escuadronId = userDoc.data()?['idEscuadronActual'] as String?;
      if (escuadronId != null) {
        return getEscuadronStream(escuadronId);
      }
      return Stream.value(null);
    });
  }

  /// Lista usuarios solteros que buscan compañeros
  Future<List<String>> obtenerUsuariosDisponibles(
    String miUid,
    String? zonaPreferida,
  ) async {
    try {
      var query = _firestore
          .collection('usuarios')
          .where('idEscuadronActual', isNull: true)
          .where('tienePiso', isEqualTo: false);

      if (zonaPreferida != null && zonaPreferida.isNotEmpty) {
        query =
            query.where('lugarDeseado', isEqualTo: zonaPreferida);
      }

      final snap = await query.get();
      return snap.docs
          .where((doc) => doc.id != miUid)
          .map((doc) => doc.id)
          .toList();
    } catch (e) {
      print('Error al obtener usuarios disponibles: $e');
      return [];
    }
  }
}
