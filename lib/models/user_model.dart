import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String nombre;
  final String email;
  final String fotoPerfil;
  final DateTime fechaNacimiento;
  final String genero;
  final String origen;
  final String estudios;
  final bool esFumador;
  final bool tieneMascotas;
  final bool tienePiso;
  final double? precioAlquilerPorPersona;
  final String horario; // Mañana, Tarde, Noche
  final bool teletrabajo;
  final String frecuenciaFiestas;
  final String nivelLimpieza;
  final String bio;
  final int afinidad; // % de afinidad calculado
  final String lugarDeseado;
  final double karma;
  final int biziPuntos;
  final String? voiceBioUrl;

  UserModel({
    required this.id,
    required this.nombre,
    required this.email,
    required this.fotoPerfil,
    required this.fechaNacimiento,
    required this.genero,
    required this.origen,
    required this.estudios,
    required this.esFumador,
    required this.tieneMascotas,
    required this.tienePiso,
    this.precioAlquilerPorPersona,
    required this.horario,
    this.teletrabajo = false,
    this.frecuenciaFiestas = 'Media',
    this.nivelLimpieza = 'Normal',
    required this.bio,
    this.afinidad = 0,
    this.lugarDeseado = '',
    this.karma = 0,
    this.biziPuntos = 0,
    this.voiceBioUrl,
  });

  // Calcular edad automáticamente
  int get edad {
    final ahora = DateTime.now();
    int edad = ahora.year - fechaNacimiento.year;
    if (ahora.month < fechaNacimiento.month ||
        (ahora.month == fechaNacimiento.month &&
            ahora.day < fechaNacimiento.day)) {
      edad--;
    }
    return edad;
  }

  // Convertir a Map para guardar en Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'fotoPerfil': fotoPerfil,
      'fechaNacimiento': fechaNacimiento,
      'genero': genero,
      'origen': origen,
      'estudios': estudios,
      'esFumador': esFumador,
      'tieneMascotas': tieneMascotas,
      'tienePiso': tienePiso,
      'precioAlquilerPorPersona': precioAlquilerPorPersona,
      'horario': horario,
      'teletrabajo': teletrabajo,
      'frecuenciaFiestas': frecuenciaFiestas,
      'nivelLimpieza': nivelLimpieza,
      'bio': bio,
      'karma': karma,
      'biziPuntos': biziPuntos,
      'voiceBioUrl': voiceBioUrl,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  // Crear desde Firebase
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromFirestore(data, id: doc.id);
  }

  factory UserModel.fromFirestore(Map<String, dynamic> data, {String id = ''}) {
    return UserModel(
      id: id,
      nombre: data['nombre'] ?? '',
      email: data['email'] ?? '',
      fotoPerfil: data['fotoPerfil'] ?? '',
      fechaNacimiento: (data['fechaNacimiento'] as Timestamp).toDate(),
      genero: data['genero'] ?? '',
      origen: data['origen'] ?? '',
      estudios: data['estudios'] ?? '',
      esFumador: data['esFumador'] ?? false,
      tieneMascotas: data['tieneMascotas'] ?? false,
      tienePiso: data['tienePiso'] ?? false,
      precioAlquilerPorPersona: (data['precioAlquilerPorPersona'] as num?)
          ?.toDouble(),
      horario: data['horario'] ?? '',
      teletrabajo: data['teletrabajo'] ?? false,
      frecuenciaFiestas: data['frecuenciaFiestas'] ?? 'Media',
      nivelLimpieza: data['nivelLimpieza'] ?? 'Normal',
      bio: data['bio'] ?? '',
      karma: (data['karma'] as num?)?.toDouble() ?? 0,
      biziPuntos: (data['biziPuntos'] as num?)?.toInt() ?? 0,
      voiceBioUrl: data['voiceBioUrl'] as String?,
    );
  }
}
