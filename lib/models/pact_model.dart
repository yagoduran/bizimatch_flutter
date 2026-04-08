import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa una regla dentro del Pacto de Convivencia
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

/// Representa el Pacto de Convivencia entre dos usuarios
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

  /// Convierte el modelo a un mapa para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'reglas': reglas.map((r) => r.toMap()).toList(),
      'estado_firmas': estadoFirmas,
      'esta_cerrado': estaCerrado,
      'fecha_creacion': fechaCreacion ?? FieldValue.serverTimestamp(),
    };
  }

  /// Crea una instancia de Pact desde un documento de Firestore
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

  /// Crea un Pact vacío con reglas predefinidas
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

  /// Actualiza una regla existente o ne agrega una nueva
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

  /// Agrega una nueva regla
  Pact agregarRegla(Regla regla) {
    return Pact(
      id: id,
      reglas: [...reglas, regla],
      estadoFirmas: estadoFirmas,
      estaCerrado: estaCerrado,
      fechaCreacion: fechaCreacion,
    );
  }

  /// Elimina una regla por su índice
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

  /// Marca el pacto como firmado por un usuario
  Pact firmarPor(String uid) {
    final nuevoEstadoFirmas = Map<String, bool>.from(estadoFirmas);
    nuevoEstadoFirmas[uid] = true;

    final ahora = estaCerrado == false && _ambosHanFirmado(nuevoEstadoFirmas);

    return Pact(
      id: id,
      reglas: reglas,
      estadoFirmas: nuevoEstadoFirmas,
      estaCerrado: ahora,
      fechaCreacion: fechaCreacion,
    );
  }

  /// Verifica si ambos usuarios han firmado
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
