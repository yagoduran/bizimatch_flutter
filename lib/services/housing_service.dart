import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/housing_model.dart';
import '../models/escuadron_model.dart';
import '../repositories/firestore_repository.dart';

/// HousingService: etxebizitzen bilaketa, like eta sortze funtzionalitatea kudeatzen du.
///
/// Zer egiten duen:
/// - Escuadron-aren beharrak kontuan hartuta etxebizitzak filtratzen ditu.
/// - Jabetzako etxebizitzen sortzea eta erabiltzaileen interaction-ak eguneratzen ditu.
class HousingService {
  static final HousingService instance = HousingService._internal();
  final FirestoreRepository _repo = FirestoreRepository.instance;
  FirebaseFirestore get _firestore => _repo.firestore;

  HousingService._internal();

  /// Obtiene viviendas completas filtradas para un escuadrón específico
  Future<List<Housing>> getHousingForSquad(Escuadron squad) async {
    /// Escuadron baten arabera egokiak diren etxebizitzak itzultzen ditu.
    try {
      final prefs = squad.preferenciasComunas;
      var query = _firestore
          .collection('viviendas')
          .where('viviendasCompleta', isEqualTo: true)
          .where('estaActiva', isEqualTo: true)
          .where(
            'numHabitaciones',
            isGreaterThanOrEqualTo: squad.miembrosCount,
          );

      // Ezarritako prefentzietarako zona filtraketa aplikatu.
      if (prefs.zona != null && prefs.zona!.isNotEmpty) {
        query = query.where('zona', isEqualTo: prefs.zona);
      }

      // Prezio maximoaren arabera filtraketa aplikatu.
      if (prefs.precioMaximo != null && prefs.precioMaximo! > 0) {
        query = query.where(
          'precioMensual',
          isLessThanOrEqualTo: prefs.precioMaximo,
        );
      }

      final snap = await query.get();

      return snap.docs.map((doc) => Housing.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error obteniendo viviendas para escuadrón: $e');
      return [];
    }
  }

  /// Stream en tiempo real de viviendas para escuadrón
  Stream<List<Housing>> getHousingStreamForSquad(Escuadron squad) {
    /// Escuadron-ari dagokion etxebizitzen stream-a itzultzen du (aldaketak realtime).
    try {
      final prefs = squad.preferenciasComunas;
      var query = _firestore
          .collection('viviendas')
          .where('viviendasCompleta', isEqualTo: true)
          .where('estaActiva', isEqualTo: true)
          .where(
            'numHabitaciones',
            isGreaterThanOrEqualTo: squad.miembrosCount,
          );

      if (prefs.zona != null && prefs.zona!.isNotEmpty) {
        query = query.where('zona', isEqualTo: prefs.zona);
      }

      if (prefs.precioMaximo != null && prefs.precioMaximo! > 0) {
        query = query.where(
          'precioMensual',
          isLessThanOrEqualTo: prefs.precioMaximo,
        );
      }

      return query.snapshots().map(
        (snap) => snap.docs.map((doc) => Housing.fromFirestore(doc)).toList(),
      );
    } catch (e) {
      print('Error en stream de viviendas: $e');
      return Stream.value([]);
    }
  }

  /// Da like a una vivienda desde un usuario
  Future<void> likeHousing(String housingId, String userId) async {
    /// Erabiltzaileak etxebizitza bati like ematen dionean eguneraketa egiten du.
    try {
      await _firestore.collection('viviendas').doc(housingId).update({
        'likesDeUsuarios.$userId': true,
        'numInteresados': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error al dar like a vivienda: $e');
    }
  }

  /// Quita like a una vivienda
  Future<void> unlikeHousing(String housingId, String userId) async {
    /// Erabiltzaileak like kentzen duenean eguneraketak burutu.
    try {
      await _firestore.collection('viviendas').doc(housingId).update({
        'likesDeUsuarios.$userId': FieldValue.delete(),
        'numInteresados': FieldValue.increment(-1),
      });
    } catch (e) {
      print('Error al quitar like a vivienda: $e');
    }
  }

  /// Verifica si TODOS los miembros del escuadrón han dado like a una vivienda
  Future<bool> allSquadMembersLiked(
    String housingId,
    List<String> squadMemberIds,
  ) async {
    /// Egiaztatu talde osoak like eman dion ala ez etxebizitzari.
    try {
      final doc = await _firestore.collection('viviendas').doc(housingId).get();
      if (!doc.exists) return false;

      final housing = Housing.fromFirestore(doc);
      final allLiked = squadMemberIds.every((uid) => housing.usuarioLaDio(uid));

      return allLiked;
    } catch (e) {
      print('Error verificando likes de escuadrón: $e');
      return false;
    }
  }

  /// Crea una vivienda nueva (para dueños)
  Future<String> createHousing({
    required String titulo,
    required String descripcion,
    required String direccion,
    required String zona,
    required double latitud,
    required double longitud,
    required int numHabitaciones,
    required int numBanyos,
    required double metrosCuadrados,
    required double precioMensual,
    required List<String> fotos,
    required List<String> comodidades,
    required String propietarioUid,
    required String nombrePropietario,
    required String telefonoPropietario,
  }) async {
    /// Propietarioek etxebizitza berri bat sortzeko erabiliko duten funtzioa.
    try {
      final docRef = _firestore.collection('viviendas').doc();
      final housing = Housing(
        id: docRef.id,
        titulo: titulo,
        descripcion: descripcion,
        direccion: direccion,
        zona: zona,
        latitud: latitud,
        longitud: longitud,
        numHabitaciones: numHabitaciones,
        numBanyos: numBanyos,
        metrosCuadrados: metrosCuadrados,
        precioMensual: precioMensual,
        viviendasCompleta: true,
        fotos: fotos,
        comodidades: comodidades,
        propietarioUid: propietarioUid,
        nombrePropietario: nombrePropietario,
        telefonoPropietario: telefonoPropietario,
        fechaCreacion: DateTime.now(),
      );

      await docRef.set(housing.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creando vivienda: $e');
      rethrow;
    }
  }

  /// Obtiene una vivienda específica
  Future<Housing?> getHousing(String housingId) async {
    /// ID bat emanda etxebizitzaren datuak itzultzen ditu.
    try {
      final doc = await _firestore.collection('viviendas').doc(housingId).get();
      if (doc.exists) {
        return Housing.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error obteniendo vivienda: $e');
      return null;
    }
  }

  /// Obtiene todas las viviendas completascompromisos (sin filtro de escuadrón)
  Future<List<Housing>> getAllActiveHousing() async {
    /// Aktibo dauden eta `viviendasCompleta` diren etxebizitzen zerrenda bueltatzen du.
    try {
      final snap = await _firestore
          .collection('viviendas')
          .where('viviendasCompleta', isEqualTo: true)
          .where('estaActiva', isEqualTo: true)
          .get();

      return snap.docs.map((doc) => Housing.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error obteniendo todas las viviendas: $e');
      return [];
    }
  }
}
