import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/housing_model.dart';
import '../models/escuadron_model.dart';

class HousingService {
  static final HousingService instance = HousingService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  HousingService._internal();

  /// Obtiene viviendas completas filtradas para un escuadrón específico
  Future<List<Housing>> getHousingForSquad(Escuadron squad) async {
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

      // Aplicar filtros de zona si existen preferencias
      if (prefs.zona != null && prefs.zona!.isNotEmpty) {
        query = query.where('zona', isEqualTo: prefs.zona);
      }

      // Aplicar filtro de precio máximo
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
