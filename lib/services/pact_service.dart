import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pact_model.dart';
import '../repositories/firestore_repository.dart';

class PactService {
  static final PactService instance = PactService._internal();
  final FirestoreRepository _repo = FirestoreRepository.instance;
  FirebaseFirestore get _firestore => _repo.firestore;

  PactService._internal();

  /// Obtiene o crea un pacto para un chat específico
  Future<Pact> getOrCreatePact(String chatId) async {
    try {
      final docSnap = await _firestore.collection('pactos').doc(chatId).get();

      if (docSnap.exists) {
        return Pact.fromFirestore(docSnap);
      }

      // Si no existe, crear uno nuevo con reglas predefinidas
      await _firestore
          .collection('pactos')
          .doc(chatId)
          .set(Pact.empty(chatId).toMap());

      return Pact.empty(chatId);
    } catch (e) {
      print('Error en getOrCreatePact: $e');
      return Pact.empty(chatId);
    }
  }

  /// Stream en tiempo real del pacto
  Stream<Pact> getPactStream(String chatId) {
    return _firestore
        .collection('pactos')
        .doc(chatId)
        .snapshots()
        .map((doc) => Pact.fromFirestore(doc));
  }

  /// Actualiza una regla específica
  Future<void> actualizarRegla(
    String chatId,
    int indiceRegla,
    Regla reglaActualizada,
  ) async {
    try {
      final pactDoc = await _firestore.collection('pactos').doc(chatId).get();
      if (!pactDoc.exists) {
        return;
      }

      final pact = Pact.fromFirestore(pactDoc);
      final pactActualizado = pact.actualizarRegla(
        indiceRegla,
        reglaActualizada,
      );

      await _firestore.collection('pactos').doc(chatId).update({
        'reglas': pactActualizado.reglas.map((r) => r.toMap()).toList(),
      });
    } catch (e) {
      print('Error al actualizar regla: $e');
    }
  }

  /// Agrega una nueva regla personalizada
  Future<void> agregarReglaPersonalizada(
    String chatId,
    String tituloRegla,
  ) async {
    try {
      final pactDoc = await _firestore.collection('pactos').doc(chatId).get();
      if (!pactDoc.exists) {
        return;
      }

      final pact = Pact.fromFirestore(pactDoc);
      final nuevaRegla = Regla(titulo: tituloRegla, completado: false);
      final pactActualizado = pact.agregarRegla(nuevaRegla);

      await _firestore.collection('pactos').doc(chatId).update({
        'reglas': pactActualizado.reglas.map((r) => r.toMap()).toList(),
      });
    } catch (e) {
      print('Error al agregar regla personalizada: $e');
    }
  }

  /// Elimina una regla por su índice
  Future<void> eliminarRegla(String chatId, int indiceRegla) async {
    try {
      final pactDoc = await _firestore.collection('pactos').doc(chatId).get();
      if (!pactDoc.exists) {
        return;
      }

      final pact = Pact.fromFirestore(pactDoc);
      final pactActualizado = pact.eliminarRegla(indiceRegla);

      await _firestore.collection('pactos').doc(chatId).update({
        'reglas': pactActualizado.reglas.map((r) => r.toMap()).toList(),
      });
    } catch (e) {
      print('Error al eliminar regla: $e');
    }
  }

  /// Firma el pacto por parte del usuario actual
  Future<void> firmarPacto(String chatId, String uid) async {
    try {
      final pactDoc = await _firestore.collection('pactos').doc(chatId).get();
      if (!pactDoc.exists) {
        // Si no existe, crearlo primero
        final nuevoPact = Pact.empty(chatId)..firmarPor(uid);
        await _firestore
            .collection('pactos')
            .doc(chatId)
            .set(nuevoPact.toMap());
      } else {
        final pact = Pact.fromFirestore(pactDoc);
        final pactActualizado = pact.firmarPor(uid);

        await _firestore.collection('pactos').doc(chatId).update({
          'estado_firmas': pactActualizado.estadoFirmas,
          'esta_cerrado': pactActualizado.estaCerrado,
        });
      }
    } catch (e) {
      print('Error al firmar pacto: $e');
    }
  }

  /// Obtiene el estado de firma actual
  Future<bool> haPorFirmado(String chatId, String uid) async {
    try {
      final pactDoc = await _firestore.collection('pactos').doc(chatId).get();
      if (!pactDoc.exists) {
        return false;
      }

      final pact = Pact.fromFirestore(pactDoc);
      return pact.estadoFirmas[uid] ?? false;
    } catch (e) {
      print('Error al verificar firma: $e');
      return false;
    }
  }

  /// Verifica si el pacto está cerrado (ambos han firmado)
  Future<bool> estaCerrado(String chatId) async {
    try {
      final pactDoc = await _firestore.collection('pactos').doc(chatId).get();
      if (!pactDoc.exists) {
        return false;
      }

      final pact = Pact.fromFirestore(pactDoc);
      return pact.estaCerrado;
    } catch (e) {
      print('Error al verificar si está cerrado: $e');
      return false;
    }
  }

  /// Obtiene el otro usuario que debe firmar
  Future<String?> obtenerOtroUsuarioFirmante(
    String chatId,
    String miUid,
  ) async {
    try {
      final pactDoc = await _firestore.collection('pactos').doc(chatId).get();
      if (!pactDoc.exists) {
        return null;
      }

      final pact = Pact.fromFirestore(pactDoc);
      final otros = pact.estadoFirmas.keys
          .where((uid) => uid != miUid)
          .toList();

      return otros.isNotEmpty ? otros.first : null;
    } catch (e) {
      print('Error al obtener otro usuario: $e');
      return null;
    }
  }
}
