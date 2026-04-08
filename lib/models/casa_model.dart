import 'package:cloud_firestore/cloud_firestore.dart';

class Casa {
  final String idCasa;
  final List<String> miembrosIds;
  final DateTime fechaCreacion;
  final String? nombreCasa;
  final String? ubicacion;
  final bool estaActiva;

  Casa({
    required this.idCasa,
    required this.miembrosIds,
    required this.fechaCreacion,
    this.nombreCasa,
    this.ubicacion,
    this.estaActiva = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_casa': idCasa,
      'miembros_ids': miembrosIds,
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      'nombre_casa': nombreCasa,
      'ubicacion': ubicacion,
      'esta_activa': estaActiva,
    };
  }

  factory Casa.fromFirestore(Map<String, dynamic> data, {required String id}) {
    return Casa(
      idCasa: id,
      miembrosIds: List<String>.from(data['miembros_ids'] ?? []),
      fechaCreacion:
          (data['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nombreCasa: data['nombre_casa'] as String?,
      ubicacion: data['ubicacion'] as String?,
      estaActiva: data['esta_activa'] as bool? ?? true,
    );
  }
}
