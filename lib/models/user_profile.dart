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
    required this.bio,
    required this.fotoPerfil,
    required this.intereses,
    this.lugarDeseado = '',
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
  final String bio;
  final String fotoPerfil;
  final List<String> intereses;
  final String lugarDeseado;

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
      'bio': bio,
      'fotoPerfil': fotoPerfil,
      'intereses': intereses,
      'lugarDeseado': lugarDeseado,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (precioAlquilerPorPersona != null) {
      map['precioAlquilerPorPersona'] = precioAlquilerPorPersona;
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
      bio: (map['bio'] ?? 'Sin bio por ahora.') as String,
      fotoPerfil: (map['fotoPerfil'] ?? '') as String,
      intereses: List<String>.from(map['intereses'] ?? const <String>[]),
      lugarDeseado: (map['lugarDeseado'] ?? '') as String,
    );
  }
}
