import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.nombre,
    required this.fechaNacimiento,
    required this.genero,
    required this.origen,
    required this.fumador,
    required this.mascotas,
    required this.horario,
    required this.bio,
    required this.fotoPerfil,
    required this.intereses,
  });

  final String uid;
  final String nombre;
  final DateTime fechaNacimiento;
  final String genero;
  final String origen;
  final bool fumador;
  final bool mascotas;
  final String horario;
  final String bio;
  final String fotoPerfil;
  final List<String> intereses;

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
    return {
      'uid': uid,
      'nombre': nombre,
      'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
      'genero': genero,
      'origen': origen,
      'fumador': fumador,
      'mascotas': mascotas,
      'horario': horario,
      'bio': bio,
      'fotoPerfil': fotoPerfil,
      'intereses': intereses,
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
      nombre: (map['nombre'] ?? 'Usuario') as String,
      fechaNacimiento: fecha,
      genero: (map['genero'] ?? 'Prefiero no decirlo') as String,
      origen: (map['origen'] ?? 'No indicado') as String,
      fumador: (map['fumador'] ?? false) as bool,
      mascotas: (map['mascotas'] ?? false) as bool,
      horario: (map['horario'] ?? 'Manana') as String,
      bio: (map['bio'] ?? 'Sin bio por ahora.') as String,
      fotoPerfil: (map['fotoPerfil'] ?? '') as String,
      intereses: List<String>.from(map['intereses'] ?? const <String>[]),
    );
  }
}
