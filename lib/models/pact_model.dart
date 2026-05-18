import 'package:cloud_firestore/cloud_firestore.dart';

/// Regla: pact-eko arau bakar baten eredu sinplea.
///
/// Atributuak: `titulo` eta `completado`.
/// `toMap` eta `fromMap` erabil daitezke Firestore-rekin erraz maniobrar.
class Regla {
  final String titulo;
  final bool completado;

  Regla({required this.titulo, required this.completado});

  Map<String, dynamic> toMap() {
    return {'titulo': titulo, 'completado': completado};
  }

  factory Regla.fromMap(Map<String, dynamic> map) {
    return Regla(
      titulo: map['titulo'] ?? '',
      completado: map['completado'] ?? false,
    );
  }

  Regla copyWith({String? titulo, bool? completado}) {
    return Regla(
      titulo: titulo ?? this.titulo,
      completado: completado ?? this.completado,
    );
  }

  @override
  String toString() => 'Regla(titulo: $titulo, completado: $completado)';
}

/// Pact: bizikidetzarako hitzarmenaren eredu nagusia.
///
/// Barne-egitura: `reglas`, `estadoFirmas` eta egoera (itxita ala ez).
class Pact {
  final String id; // chatId
  final List<Regla> reglas;
  final Map<String, bool> estadoFirmas; // {'uid1': true, 'uid2': false}
  final bool estaCerrado; // true cuando ambos firman
  final DateTime? fechaCreacion;

  Pact({
    required this.id,
    required this.reglas,
    required this.estadoFirmas,
    this.estaCerrado = false,
    this.fechaCreacion,
  });

  /// `Pact` objektua map bat bilakatzen du Firestore-era gordetzeko.
  Map<String, dynamic> toMap() {
    return {
      'reglas': reglas.map((r) => r.toMap()).toList(),
      'estado_firmas': estadoFirmas,
      'esta_cerrado': estaCerrado,
      'fecha_creacion': fechaCreacion ?? FieldValue.serverTimestamp(),
    };
  }

  /// Firestore dokumentutik `Pact` objektua sortzen du.
  factory Pact.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      return Pact.empty(doc.id);
    }

    final data = doc.data() as Map<String, dynamic>;
    final reglasData = (data['reglas'] as List<dynamic>?) ?? [];
    final reglas = reglasData
        .map((r) => Regla.fromMap(r as Map<String, dynamic>))
        .toList();

    return Pact(
      id: doc.id,
      reglas: reglas,
      estadoFirmas: Map<String, bool>.from(data['estado_firmas'] ?? {}),
      estaCerrado: data['esta_cerrado'] ?? false,
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate(),
    );
  }

  /// Hutseko `Pact` bat sortzen du arau predefinituekin.
  factory Pact.empty(String chatId) {
    return Pact(
      id: chatId,
      reglas: [
        Regla(titulo: 'Limpieza', completado: false),
        Regla(titulo: 'Visitas', completado: false),
        Regla(titulo: 'Ruido', completado: false),
        Regla(titulo: 'Gastos', completado: false),
      ],
      estadoFirmas: {},
      estaCerrado: false,
      fechaCreacion: DateTime.now(),
    );
  }

  /// Araudi bat eguneratzen du index baten bidez edo lehengoratzea egiten du.
  Pact actualizarRegla(int index, Regla reglaActualizada) {
    final nuevasReglas = List<Regla>.from(reglas);
    if (index >= 0 && index < nuevasReglas.length) {
      nuevasReglas[index] = reglaActualizada;
    }
    return Pact(
      id: id,
      reglas: nuevasReglas,
      estadoFirmas: estadoFirmas,
      estaCerrado: estaCerrado,
      fechaCreacion: fechaCreacion,
    );
  }

  /// Araudi berri bat gehitzen du pact-era.
  Pact agregarRegla(Regla regla) {
    return Pact(
      id: id,
      reglas: [...reglas, regla],
      estadoFirmas: estadoFirmas,
      estaCerrado: estaCerrado,
      fechaCreacion: fechaCreacion,
    );
  }

  /// Indize bidez arau bat ezabatzen du.
  Pact eliminarRegla(int index) {
    final nuevasReglas = List<Regla>.from(reglas);
    if (index >= 0 && index < nuevasReglas.length) {
      nuevasReglas.removeAt(index);
    }
    return Pact(
      id: id,
      reglas: nuevasReglas,
      estadoFirmas: estadoFirmas,
      estaCerrado: estaCerrado,
      fechaCreacion: fechaCreacion,
    );
  }

  /// Erabiltzaile batek sinatzen duenean egoera eguneratzen du eta egiaztatzen du.
  Pact firmarPor(String uid) {
    final nuevoEstadoFirmas = Map<String, bool>.from(estadoFirmas);
    nuevoEstadoFirmas[uid] = true;
    // Bi aldeak sinatu dituen egiaztatu eta `estaCerrado` aldagarria aktibatu.
    final ahora = estaCerrado == false && _ambosHanFirmado(nuevoEstadoFirmas);

    return Pact(
      id: id,
      reglas: reglas,
      estadoFirmas: nuevoEstadoFirmas,
      estaCerrado: ahora,
      fechaCreacion: fechaCreacion,
    );
  }

  /// Bi sinatzaileek sinatu duten egiaztatzen du (eta kopurua 2 dela egiaztatzen).
  bool _ambosHanFirmado(Map<String, bool> firmas) {
    return firmas.values.every((value) => value == true) && firmas.length == 2;
  }

  Pact copyWith({
    String? id,
    List<Regla>? reglas,
    Map<String, bool>? estadoFirmas,
    bool? estaCerrado,
    DateTime? fechaCreacion,
  }) {
    return Pact(
      id: id ?? this.id,
      reglas: reglas ?? this.reglas,
      estadoFirmas: estadoFirmas ?? this.estadoFirmas,
      estaCerrado: estaCerrado ?? this.estaCerrado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  @override
  String toString() =>
      'Pact(id: $id, reglas: $reglas, estaCerrado: $estaCerrado)';
}
