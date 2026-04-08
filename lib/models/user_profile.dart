import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    this.email = '',
    required this.nombre,
    required this.fechaNacimiento,
    required this.genero,
    required this.origen,
    required this.estudios,
    required this.fumador,
    required this.mascotas,
    required this.tienePiso,
    this.precioAlquilerPorPersona,
    required this.horario,
    this.teletrabajo = false,
    this.frecuenciaFiestas = 'Media',
    this.nivelLimpieza = 'Normal',
    required this.bio,
    required this.fotoPerfil,
    required this.intereses,
    this.lugarDeseado = '',
    this.direccionZona = '',
    this.fotosPiso = const <String>[],
    this.karma,
    this.totalResenas,
    this.medallasResumen,
  });

  final String uid;
  final String email;
  final String nombre;
  final DateTime fechaNacimiento;
  final String genero;
  final String origen;
  final String estudios;
  final bool fumador;
  final bool mascotas;
  final bool tienePiso;
  final int? precioAlquilerPorPersona;
  final String horario;
  final bool teletrabajo;
  final String frecuenciaFiestas;
  final String nivelLimpieza;
  final String bio;
  final String fotoPerfil;
  final List<String> intereses;
  final String lugarDeseado;
  final String direccionZona;
  final List<String> fotosPiso;
  final double? karma;
  final int? totalResenas;
  final Map<String, int>? medallasResumen;

  int get edad {
    final now = DateTime.now();
    int years = now.year - fechaNacimiento.year;
    final hasHadBirthday =
        now.month > fechaNacimiento.month ||
        (now.month == fechaNacimiento.month && now.day >= fechaNacimiento.day);
    if (!hasHadBirthday) {
      years -= 1;
    }
    return years;
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'email': email,
      'nombre': nombre,
      'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
      'genero': genero,
      'origen': origen,
      'estudios': estudios,
      'fumador': fumador,
      'mascotas': mascotas,
      'tienePiso': tienePiso,
      'horario': horario,
      'teletrabajo': teletrabajo,
      'frecuenciaFiestas': frecuenciaFiestas,
      'nivelLimpieza': nivelLimpieza,
      'bio': bio,
      'fotoPerfil': fotoPerfil,
      'intereses': intereses,
      'lugarDeseado': lugarDeseado,
      'direccionZona': direccionZona,
      'fotosPiso': fotosPiso,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (precioAlquilerPorPersona != null) {
      map['precioAlquilerPorPersona'] = precioAlquilerPorPersona;
    }

    if (karma != null) {
      map['karma'] = karma;
    }
    if (totalResenas != null) {
      map['totalResenas'] = totalResenas;
    }
    if (medallasResumen != null) {
      map['medallasResumen'] = medallasResumen;
    }

    return map;
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final dynamic rawFecha = map['fechaNacimiento'];
    DateTime fecha = DateTime(2000, 1, 1);
    if (rawFecha is Timestamp) {
      fecha = rawFecha.toDate();
    } else if (rawFecha is String) {
      fecha = DateTime.tryParse(rawFecha) ?? fecha;
    }

    return UserProfile(
      uid: (map['uid'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      nombre: (map['nombre'] ?? 'Usuario') as String,
      fechaNacimiento: fecha,
      genero: (map['genero'] ?? 'Prefiero no decirlo') as String,
      origen: (map['origen'] ?? 'No indicado') as String,
      estudios: (map['estudios'] ?? 'No indicado') as String,
      fumador: (map['fumador'] ?? false) as bool,
      mascotas: (map['mascotas'] ?? false) as bool,
      tienePiso: (map['tienePiso'] ?? false) as bool,
      precioAlquilerPorPersona: (map['precioAlquilerPorPersona'] as num?)
          ?.toInt(),
      horario: (map['horario'] ?? 'Manana') as String,
      teletrabajo: (map['teletrabajo'] ?? false) as bool,
      frecuenciaFiestas: (map['frecuenciaFiestas'] ?? 'Media') as String,
      nivelLimpieza: (map['nivelLimpieza'] ?? 'Normal') as String,
      bio: (map['bio'] ?? 'Sin bio por ahora.') as String,
      fotoPerfil: (map['fotoPerfil'] ?? '') as String,
      intereses: List<String>.from(map['intereses'] ?? const <String>[]),
      lugarDeseado: (map['lugarDeseado'] ?? '') as String,
      direccionZona: (map['direccionZona'] ?? '') as String,
      fotosPiso: List<String>.from(map['fotosPiso'] ?? const <String>[]),
      karma: (map['karma'] as num?)?.toDouble(),
      totalResenas: (map['totalResenas'] as num?)?.toInt(),
      medallasResumen: (map['medallasResumen'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
    );
  }
}

class UserReview {
  const UserReview({
    required this.id,
    required this.autorId,
    required this.texto,
    required this.tipoMedalla,
    required this.createdAt,
  });

  final String id;
  final String autorId;
  final String texto;
  final String tipoMedalla;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'autorId': autorId,
      'texto': texto,
      'tipoMedalla': tipoMedalla,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  factory UserReview.fromDoc(String id, Map<String, dynamic> map) {
    return UserReview(
      id: id,
      autorId: (map['autorId'] ?? '') as String,
      texto: (map['texto'] ?? '') as String,
      tipoMedalla: (map['tipoMedalla'] ?? '') as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
