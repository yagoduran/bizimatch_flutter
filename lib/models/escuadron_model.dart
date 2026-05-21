import 'package:cloud_firestore/cloud_firestore.dart';

/// PreferenciasComunes: escuadrón-en partekaturiko irizpideak (prezio, zona).
class PreferenciasComunes {
  final double? precioMaximo; // máximo precio de alquiler
  final String? zona; // zona preferida

  PreferenciasComunes({this.precioMaximo, this.zona});

  Map<String, dynamic> toMap() {
    return {'precioMaximo': precioMaximo, 'zona': zona};
  }

  factory PreferenciasComunes.fromMap(Map<String, dynamic> map) {
    return PreferenciasComunes(
      precioMaximo: (map['precioMaximo'] as num?)?.toDouble(),
      zona: map['zona'] as String?,
    );
  }

  factory PreferenciasComunes.empty() {
    return PreferenciasComunes();
  }
}

/// Escuadron: talde txiki baten (max 3) eredu nagusia, kideak eta preferentziak barne.
class Escuadron {
  final String idEscuadron;
  final List<String> listaMiembrosIds; // máx 3
  final PreferenciasComunes preferenciasComunas;
  final bool estaActivo;
  final DateTime fechaCreacion;

  String get id => idEscuadron;
  List<String> get members => listaMiembrosIds;
  bool get isActive => estaActivo;
  DateTime get createdAt => fechaCreacion;

  Escuadron({
    required this.idEscuadron,
    required this.listaMiembrosIds,
    required this.preferenciasComunas,
    required this.estaActivo,
    required this.fechaCreacion,
  });

  int get miembrosCount => listaMiembrosIds.length;
  bool get puedeAnadirMiembro => miembrosCount < 3;

  Map<String, dynamic> toMap() {
    return {
      'id': idEscuadron,
      'members': listaMiembrosIds,
      'isActive': estaActivo,
      'createdAt': fechaCreacion,
      'idEscuadron': idEscuadron,
      'listaMiembrosIds': listaMiembrosIds,
      'preferenciasComunas': preferenciasComunas.toMap(),
      'estaActivo': estaActivo,
      'fechaCreacion': fechaCreacion,
    };
  }

  factory Escuadron.fromFirestore(DocumentSnapshot doc) {
    // Firestore dokumentutik Escuadron objektua sortu.
    final data = doc.data() as Map<String, dynamic>;
    final members = List<String>.from(
      data['members'] ?? data['listaMiembrosIds'] ?? const <String>[],
    );
    return Escuadron(
      idEscuadron: doc.id,
      listaMiembrosIds: members,
      preferenciasComunas: PreferenciasComunes.fromMap(
        (data['preferenciasComunas'] as Map<String, dynamic>?) ??
            {'precioMaximo': null, 'zona': null},
      ),
      estaActivo: (data['isActive'] ?? data['estaActivo'] ?? true) as bool,
      fechaCreacion:
          (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['fechaCreacion'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  factory Escuadron.empty(String idEscuadron, List<String> miembrosIds) {
    return Escuadron(
      idEscuadron: idEscuadron,
      listaMiembrosIds: miembrosIds,
      preferenciasComunas: PreferenciasComunes.empty(),
      estaActivo: true,
      fechaCreacion: DateTime.now(),
    );
  }

  Escuadron anadirMiembro(String uid) {
    if (puedeAnadirMiembro && !listaMiembrosIds.contains(uid)) {
      return Escuadron(
        idEscuadron: idEscuadron,
        listaMiembrosIds: [...listaMiembrosIds, uid],
        preferenciasComunas: preferenciasComunas,
        estaActivo: estaActivo,
        fechaCreacion: fechaCreacion,
      );
    }
    return this;
  }

  Escuadron removerMiembro(String uid) {
    return Escuadron(
      idEscuadron: idEscuadron,
      listaMiembrosIds: listaMiembrosIds.where((id) => id != uid).toList(),
      preferenciasComunas: preferenciasComunas,
      estaActivo: estaActivo,
      fechaCreacion: fechaCreacion,
    );
  }

  Escuadron actualizarPreferencias(PreferenciasComunes nuevas) {
    return Escuadron(
      idEscuadron: idEscuadron,
      listaMiembrosIds: listaMiembrosIds,
      preferenciasComunas: nuevas,
      estaActivo: estaActivo,
      fechaCreacion: fechaCreacion,
    );
  }

  Escuadron desactivar() {
    return Escuadron(
      idEscuadron: idEscuadron,
      listaMiembrosIds: listaMiembrosIds,
      preferenciasComunas: preferenciasComunas,
      estaActivo: false,
      fechaCreacion: fechaCreacion,
    );
  }
}
