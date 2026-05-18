import 'package:cloud_firestore/cloud_firestore.dart';

enum TareaCategoria { limpieza, compras, pagos, reparaciones, otro }

/// Tarea: etxeko zeregin bati lotutako eredu bat.
///
/// Atributuak: puntuazioa, asignatua den erabiltzailea, epea, kategoria eta abar.
class Tarea {
  final String idTarea;
  final String idCasa;
  final String titulo;
  final String? descripcion;
  final int puntos;
  final String asignadoA;
  final bool completada;
  final DateTime fechaLimite;
  final DateTime? fechaCompletada;
  final TareaCategoria categoria;
  final bool recurrente;

  Tarea({
    required this.idTarea,
    required this.idCasa,
    required this.titulo,
    this.descripcion,
    required this.puntos,
    required this.asignadoA,
    required this.completada,
    required this.fechaLimite,
    this.fechaCompletada,
    required this.categoria,
    this.recurrente = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_tarea': idTarea,
      'id_casa': idCasa,
      'titulo': titulo,
      'descripcion': descripcion,
      'puntos': puntos,
      'asignado_a': asignadoA,
      'completada': completada,
      'fecha_limite': Timestamp.fromDate(fechaLimite),
      'fecha_completada': fechaCompletada != null
          ? Timestamp.fromDate(fechaCompletada!)
          : null,
      'categoria': _categoriaTiString(categoria),
      'recurrente': recurrente,
    };
  }

  factory Tarea.fromFirestore(Map<String, dynamic> data, {required String id}) {
    // Firestore dokumentutik `Tarea` objektua sortu, data parsing barne.
    return Tarea(
      idTarea: id,
      idCasa: data['id_casa'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String?,
      puntos: data['puntos'] as int? ?? 0,
      asignadoA: data['asignado_a'] as String? ?? '',
      completada: data['completada'] as bool? ?? false,
      fechaLimite:
          (data['fecha_limite'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaCompletada: (data['fecha_completada'] as Timestamp?)?.toDate(),
      categoria: _stringACategoria(data['categoria'] as String? ?? 'otro'),
      recurrente: data['recurrente'] as bool? ?? false,
    );
  }

  Tarea copyWith({bool? completada, DateTime? fechaCompletada}) {
    return Tarea(
      idTarea: idTarea,
      idCasa: idCasa,
      titulo: titulo,
      descripcion: descripcion,
      puntos: puntos,
      asignadoA: asignadoA,
      completada: completada ?? this.completada,
      fechaLimite: fechaLimite,
      fechaCompletada: fechaCompletada ?? this.fechaCompletada,
      categoria: categoria,
      recurrente: recurrente,
    );
  }
}

String _categoriaTiString(TareaCategoria cat) {
  return cat.toString().split('.').last;
}

TareaCategoria _stringACategoria(String str) {
  return TareaCategoria.values.firstWhere(
    (c) => c.toString().split('.').last == str,
    orElse: () => TareaCategoria.otro,
  );
}
