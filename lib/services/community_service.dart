import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/community_plan_model.dart';
import '../models/community_plan_type.dart';
import '../repositories/firestore_repository.dart';

/// CommunityService: komunitateko ekitaldi eta planen kudeaketa egiten du.
///
/// Zer egiten duen:
/// - Komunitate planak sortu, zerrendatu eta mezularitza kudeatzen du.
/// - `FirestoreRepository` erabiliz datuak irakurri/eguneratzen ditu.
class CommunityService {
  CommunityService._internal();
  static final CommunityService instance = CommunityService._internal();

  final FirestoreRepository _repo = FirestoreRepository.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _planes =>
      _repo.collection('comunidad_planes');

  String get currentUid => _auth.currentUser?.uid ?? '';

  Future<String> obtenerCiudadUsuario() async {
    /// Erabiltzailearen hiria edo lehen aukeratutako kokapena itzultzen du.
    /// Itzulera: hiria edo 'General' lehenetsi gabe.
    final uid = currentUid;
    if (uid.isEmpty) return 'General';

    final doc = await _repo.getDoc('usuarios', uid);
    final data = doc.data() ?? <String, dynamic>{};

    final raw =
        ((data['ciudad'] as String?)?.trim().isNotEmpty == true
                ? data['ciudad']
                : (data['lugarDeseado'] as String?)?.trim().isNotEmpty == true
                ? data['lugarDeseado']
                : (data['direccionZona'] as String?)?.trim().isNotEmpty == true
                ? data['direccionZona']
                : 'General')
            as String;

    final first = raw.split(',').first.trim();
    return first.isEmpty ? 'General' : first;
  }

  Stream<List<CommunityPlan>> planesPorCiudad(String ciudad) {
    /// Ematen den hiriari dagokion komunitate-planen stream-a itzultzen du.
    return _planes
        .where('ciudad', isEqualTo: ciudad)
        .orderBy('fecha_hora')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommunityPlan.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<String>> ciudadesDisponibles() {
    /// Eskuragarri dauden hirien zerrenda itzultzen du, 'General' barne.
    return _planes.snapshots().map((snapshot) {
      final cities = <String>{'General'};
      for (final doc in snapshot.docs) {
        final city = ((doc.data()['ciudad'] as String?) ?? '').trim();
        if (city.isNotEmpty) {
          cities.add(city);
        }
      }
      final list = cities.toList()..sort();
      return list;
    });
  }

  Future<void> crearPlan({
    required String titulo,
    required String descripcion,
    required String ciudad,
    required DateTime fechaHora,
    required CommunityPlanType tipoPlan,
    required String creadorNombre,
  }) async {
    /// Komunitate-plana sortzen du eta Firestore-era gordetzen du.
    /// Parametro nagusiak: `titulo`, `descripcion`, `ciudad`, `fechaHora`, `tipoPlan`.
    final uid = currentUid;
    if (uid.isEmpty) {
      throw Exception('Usuario no autenticado');
    }

    final doc = _planes.doc();
    final plan = CommunityPlan(
      id: doc.id,
      titulo: titulo,
      descripcion: descripcion,
      creadorId: uid,
      creadorNombre: creadorNombre,
      ciudad: ciudad,
      fechaHora: fechaHora,
      tipoPlan: tipoPlan,
      asistentesIds: <String>[uid],
      chatActivo: true,
      chatPlanId: doc.id,
    );

    await _repo.setDoc('comunidad_planes', doc.id, plan.toMap());
  }

  Future<void> toggleAsistencia(CommunityPlan plan) async {
    /// Ematen den pertsonak plan batean dagoen ala ez aldatu (join/leave).
    final uid = currentUid;
    if (uid.isEmpty) return;

    final ref = _planes.doc(plan.id);
    final joined = plan.asistentesIds.contains(uid);

    await ref.update({
      'asistentes_ids': joined
          ? FieldValue.arrayRemove(<String>[uid])
          : FieldValue.arrayUnion(<String>[uid]),
      'chat_activo': true,
      'chat_plan_id': plan.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CommunityPlanMessage>> mensajesPlan(String planId) {
    /// Plan jakin baten mezuen stream-a itzultzen du.
    return _planes
        .doc(planId)
        .collection('mensajes')
        .orderBy('created_at')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommunityPlanMessage.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> enviarMensajePlan({
    required String planId,
    required String texto,
    required String senderName,
  }) async {
    /// Plan baten mezua sortu eta gorde.
    /// - `texto` hutsik badago, ez du ezer egiten.
    final uid = currentUid;
    if (uid.isEmpty) return;

    final value = texto.trim();
    if (value.isEmpty) return;

    await _planes.doc(planId).collection('mensajes').add({
      'plan_id': planId,
      'sender_id': uid,
      'sender_name': senderName,
      'texto': value,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
