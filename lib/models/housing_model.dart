import 'package:cloud_firestore/cloud_firestore.dart';

/// Housing: etxebizitza (listing) bateko ereduaren definizioa.
///
/// Ezarpenak eta helper metodoak Firestore dokumentuetatik objektuetara bihurtzeko erabiliko dira.
class Housing {
  final String id;
  final String titulo;
  final String descripcion;
  final String direccion;
  final String zona; // Barrio o zona
  final double latitud;
  final double longitud;
  final int numHabitaciones;
  final int numBanyos;
  final double metrosCuadrados;
  final double precioMensual;
  final bool viviendasCompleta; // true = alojamiento completo
  final List<String> fotos; // URLs de fotos
  final List<String> comodidades; // WiFi, Cocina, Terraza, etc.
  final String propietarioUid;
  final String nombrePropietario;
  final String telefonoPropietario;
  final DateTime fechaCreacion;
  final bool estaActiva;
  final int numInteresados; // Cuántos usuarios le han dado like
  final Map<String, bool>
  likesDeUsuarios; // {uid: true/false} para rastrear likes
  final Map<String, bool> squadLikes;
  final Map<String, bool> squadOwnerLikes;

  Housing({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.direccion,
    required this.zona,
    required this.latitud,
    required this.longitud,
    required this.numHabitaciones,
    required this.numBanyos,
    required this.metrosCuadrados,
    required this.precioMensual,
    required this.viviendasCompleta,
    required this.fotos,
    required this.comodidades,
    required this.propietarioUid,
    required this.nombrePropietario,
    required this.telefonoPropietario,
    required this.fechaCreacion,
    this.estaActiva = true,
    this.numInteresados = 0,
    Map<String, bool>? likesDeUsuarios,
    Map<String, bool>? squadLikes,
    Map<String, bool>? squadOwnerLikes,
  }) : likesDeUsuarios = likesDeUsuarios ?? {},
    squadLikes = squadLikes ?? {},
    squadOwnerLikes = squadOwnerLikes ?? {};

  bool usuarioLaDio(String uid) => likesDeUsuarios[uid] ?? false;

  bool squadLaDio(String squadId) => squadLikes[squadId] ?? false;

  bool ownerAproboSquad(String squadId) => squadOwnerLikes[squadId] ?? false;

  bool squadMatchListo(String squadId) =>
      squadLaDio(squadId) && ownerAproboSquad(squadId);

  int countLikes() => likesDeUsuarios.values.where((v) => v).length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'direccion': direccion,
      'zona': zona,
      'latitud': latitud,
      'longitud': longitud,
      'numHabitaciones': numHabitaciones,
      'numBanyos': numBanyos,
      'metrosCuadrados': metrosCuadrados,
      'precioMensual': precioMensual,
      'viviendasCompleta': viviendasCompleta,
      'fotos': fotos,
      'comodidades': comodidades,
      'propietarioUid': propietarioUid,
      'nombrePropietario': nombrePropietario,
      'telefonoPropietario': telefonoPropietario,
      'fechaCreacion': fechaCreacion,
      'estaActiva': estaActiva,
      'numInteresados': numInteresados,
      'likesDeUsuarios': likesDeUsuarios,
      'squadLikes': squadLikes,
      'squadOwnerLikes': squadOwnerLikes,
    };
  }

  factory Housing.fromFirestore(DocumentSnapshot doc) {
    // Firestore dokumentutik objektu bat sortu.
    final data = doc.data() as Map<String, dynamic>;
    return Housing(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      direccion: data['direccion'] ?? '',
      zona: data['zona'] ?? '',
      latitud: (data['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (data['longitud'] as num?)?.toDouble() ?? 0.0,
      numHabitaciones: (data['numHabitaciones'] as num?)?.toInt() ?? 1,
      numBanyos: (data['numBanyos'] as num?)?.toInt() ?? 1,
      metrosCuadrados: (data['metrosCuadrados'] as num?)?.toDouble() ?? 0.0,
      precioMensual: (data['precioMensual'] as num?)?.toDouble() ?? 0.0,
      viviendasCompleta: data['viviendasCompleta'] ?? false,
      fotos: List<String>.from(data['fotos'] ?? []),
      comodidades: List<String>.from(data['comodidades'] ?? []),
      propietarioUid: data['propietarioUid'] ?? '',
      nombrePropietario: data['nombrePropietario'] ?? '',
      telefonoPropietario: data['telefonoPropietario'] ?? '',
      fechaCreacion:
          (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estaActiva: data['estaActiva'] ?? true,
      numInteresados: (data['numInteresados'] as num?)?.toInt() ?? 0,
      likesDeUsuarios: Map<String, bool>.from(data['likesDeUsuarios'] ?? {}),
      squadLikes: Map<String, bool>.from(data['squadLikes'] ?? {}),
      squadOwnerLikes: Map<String, bool>.from(data['squadOwnerLikes'] ?? {}),
    );
  }
}
