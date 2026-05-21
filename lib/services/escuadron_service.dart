import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/escuadron_model.dart';

/// EscuadronService: taldeentzako (escuadrón) logika eta Firestore eguneraketak kudeatzen ditu.
///
/// Zer egiten duen:
/// - Talde berriak sortu, kideak kudeatu, eta taldeak disolbatzen ditu.
/// - Erabiltzaileen dokumentuak eguneratzen ditu taldeen egoeraren arabera.
class EscuadronService {
  static final EscuadronService instance = EscuadronService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _squads =>
      _firestore.collection('squads');

  EscuadronService._internal();

  /// Talde berri bat sortzen du eta hasierako kideei `idEscuadronActual` gehitzen die.
  ///
  /// Parametroak: `miembrosIds` (hasierako kideen UID-ak), `precioMaximo`, `zona`.
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

      final payload = escuadronConPrefs.toMap();
      await docRef.set(payload);
      await _squads.doc(docRef.id).set(payload);

      // Erabiltzaile bakoitzaren dokumentua eguneratu, idEscuadronActual gehituz.
      for (final uid in miembrosIds) {
        await _firestore.collection('usuarios').doc(uid).update({
          'idEscuadronActual': docRef.id,
          'squadId': docRef.id,
        });
      }

      return escuadronConPrefs;
    } catch (e) {
      print('Error al crear escuadrón: $e');
      rethrow;
    }
  }

  /// Ematen den `escuadronId`-ari dagokion `Escuadron` objektua itzultzen du.
  Future<Escuadron?> obtenerEscuadron(String escuadronId) async {
    try {
      final doc = await _squads.doc(escuadronId).get();
      if (doc.exists) {
        return Escuadron.fromFirestore(doc);
      }
      final legacyDoc = await _firestore
          .collection('escuadrones')
          .doc(escuadronId)
          .get();
      if (legacyDoc.exists) {
        return Escuadron.fromFirestore(legacyDoc);
      }
      return null;
    } catch (e) {
      print('Error al obtener escuadrón: $e');
      return null;
    }
  }

  /// Escuadron baten aldaketa jarraitzen duen stream-a itzultzen du.
  Stream<Escuadron?> getEscuadronStream(String escuadronId) {
    return _squads
      .doc(escuadronId)
        .snapshots()
        .map((doc) => doc.exists ? Escuadron.fromFirestore(doc) : null);
  }

  /// Taldeari kide berri bat gehitzen dio eta erabiltzailearen erregistroa eguneratzen du.
  Future<void> anadirMiembro(String escuadronId, String nuevoUid) async {
    try {
      final escuadron = await obtenerEscuadron(escuadronId);
      if (escuadron != null &&
          escuadron.puedeAnadirMiembro &&
          !escuadron.listaMiembrosIds.contains(nuevoUid)) {
        final escuadronActualizado = escuadron.anadirMiembro(nuevoUid);

        await _squads.doc(escuadronId).update({
          'listaMiembrosIds': escuadronActualizado.listaMiembrosIds,
          'members': escuadronActualizado.listaMiembrosIds,
        });

        // Erabiltzailearen dokumentuan taldearen id-a gorde.
        await _firestore.collection('usuarios').doc(nuevoUid).update({
          'idEscuadronActual': escuadronId,
          'squadId': escuadronId,
        });
      }
    } catch (e) {
      print('Error al añadir miembro: $e');
    }
  }

  /// Taldeko kide bat kentzen du; kide gabe gelditzen bada taldeari amaiera ematen dio.
  Future<void> removerMiembro(String escuadronId, String uidARemover) async {
    try {
      final escuadron = await obtenerEscuadron(escuadronId);
      if (escuadron != null) {
        final escuadronActualizado = escuadron.removerMiembro(uidARemover);

        if (escuadronActualizado.listaMiembrosIds.isEmpty) {
          // Si no hay miembros, disolver el escuadrón
          await disolverEscuadron(escuadronId);
        } else {
          await _squads.doc(escuadronId).update({
            'listaMiembrosIds': escuadronActualizado.listaMiembrosIds,
            'members': escuadronActualizado.listaMiembrosIds,
          });
        }

        // Erabiltzailearen idEscuadronActual ezabatu.
        await _firestore.collection('usuarios').doc(uidARemover).update({
          'idEscuadronActual': FieldValue.delete(),
          'squadId': FieldValue.delete(),
        });
      }
    } catch (e) {
      print('Error al remover miembro: $e');
    }
  }

  /// Taldearen gustu eta aukerak eguneratzen ditu (precio, zona, ...).
  Future<void> actualizarPreferencias(
    String escuadronId,
    double? precioMaximo,
    String? zona,
  ) async {
    try {
      await _squads.doc(escuadronId).update({
        'preferenciasComunas': PreferenciasComunes(
          precioMaximo: precioMaximo,
          zona: zona,
        ).toMap(),
      });
    } catch (e) {
      print('Error al actualizar preferencias: $e');
    }
  }

  /// Taldea disolbatzen du: kideen dokumentuak garbitu eta taldearen egoera desaktibatu.
  Future<void> disolverEscuadron(String escuadronId) async {
    try {
      final escuadron = await obtenerEscuadron(escuadronId);
      if (escuadron != null) {
        // Kide guztien dokumentuetan idEscuadronActual ezabatu.
        for (final uid in escuadron.listaMiembrosIds) {
          await _firestore.collection('usuarios').doc(uid).update({
            'idEscuadronActual': FieldValue.delete(),
            'squadId': FieldValue.delete(),
          });
        }

        // Desactivar el escuadrón
        await _squads.doc(escuadronId).update({
          'estaActivo': false,
          'listaMiembrosIds': [],
          'members': [],
          'isActive': false,
        });
      }
    } catch (e) {
      print('Error al disolver escuadrón: $e');
    }
  }

  /// Erabiltzaile batek dagoen uneko taldearen informazioa itzultzen du.
  Future<Escuadron?> obtenerEscuadronActual(String uid) async {
    try {
      final userDoc = await _firestore.collection('usuarios').doc(uid).get();
        final escuadronId =
          (userDoc.data()?['idEscuadronActual'] as String?) ??
          (userDoc.data()?['squadId'] as String?);

      if (escuadronId != null) {
        return await obtenerEscuadron(escuadronId);
      }
      return null;
    } catch (e) {
      print('Error al obtener escuadrón actual: $e');
      return null;
    }
  }

  /// Erabiltzailearen egungo taldearen stream-a itzultzen du (aldaketak jarraitzeko).
  Stream<Escuadron?> getEscuadronActualStream(String uid) {
    return _firestore.collection('usuarios').doc(uid).snapshots().asyncExpand((
      userDoc,
    ) {
        final escuadronId =
          (userDoc.data()?['idEscuadronActual'] as String?) ??
          (userDoc.data()?['squadId'] as String?);
      if (escuadronId != null) {
        return getEscuadronStream(escuadronId);
      }
      return Stream.value(null);
    });
  }

  /// Erabiltzaile solteak zerrendatzen ditu, taldera gehitu daitezkeenak.
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
