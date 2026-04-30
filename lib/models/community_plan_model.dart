import 'package:cloud_firestore/cloud_firestore.dart';

import 'community_plan_type.dart';

class CommunityPlan {
  const CommunityPlan({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.creadorId,
    required this.creadorNombre,
    required this.ciudad,
    required this.fechaHora,
    required this.tipoPlan,
    required this.asistentesIds,
    this.chatActivo = false,
    this.chatPlanId,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final String creadorId;
  final String creadorNombre;
  final String ciudad;
  final DateTime fechaHora;
  final CommunityPlanType tipoPlan;
  final List<String> asistentesIds;
  final bool chatActivo;
  final String? chatPlanId;

  int get asistentesCount => asistentesIds.length;

  bool isAttending(String uid) => asistentesIds.contains(uid);

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'creador_id': creadorId,
      'creador_nombre': creadorNombre,
      'ciudad': ciudad,
      'fecha_hora': Timestamp.fromDate(fechaHora),
      'tipo_plan': tipoPlan.value,
      'asistentes_ids': asistentesIds,
      'chat_activo': chatActivo,
      'chat_plan_id': chatPlanId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory CommunityPlan.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CommunityPlan(
      id: doc.id,
      titulo: (data['titulo'] as String?) ?? '',
      descripcion: (data['descripcion'] as String?) ?? '',
      creadorId: (data['creador_id'] as String?) ?? '',
      creadorNombre: (data['creador_nombre'] as String?) ?? 'Usuario',
      ciudad: (data['ciudad'] as String?) ?? 'General',
      fechaHora: (data['fecha_hora'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tipoPlan: communityPlanTypeFromValue(
        (data['tipo_plan'] as String?) ?? 'otro',
      ),
      asistentesIds: List<String>.from(
        data['asistentes_ids'] ?? const <String>[],
      ),
      chatActivo: (data['chat_activo'] as bool?) ?? false,
      chatPlanId: data['chat_plan_id'] as String?,
    );
  }
}

class CommunityPlanMessage {
  const CommunityPlanMessage({
    required this.id,
    required this.planId,
    required this.senderId,
    required this.senderName,
    required this.texto,
    required this.createdAt,
  });

  final String id;
  final String planId;
  final String senderId;
  final String senderName;
  final String texto;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'plan_id': planId,
      'sender_id': senderId,
      'sender_name': senderName,
      'texto': texto,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  factory CommunityPlanMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CommunityPlanMessage(
      id: doc.id,
      planId: (data['plan_id'] as String?) ?? '',
      senderId: (data['sender_id'] as String?) ?? '',
      senderName: (data['sender_name'] as String?) ?? 'Usuario',
      texto: (data['texto'] as String?) ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
