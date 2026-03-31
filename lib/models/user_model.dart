import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String nombre;
  final String email;
  final String fotoPerfil;
  final DateTime fechaNacimiento;
  final String genero;
  final String origen;
  final bool esFumador;
  final bool tieneMascotas;
  final String horario; // Mañana, Tarde, Noche
  final String bio;
  final int afinidad; // % de afinidad calculado

  UserModel({
    required this.id,
    required this.nombre,
    required this.email,
    required this.fotoPerfil,
    required this.fechaNacimiento,
    required this.genero,
    required this.origen,
    required this.esFumador,
    required this.tieneMascotas,
    required this.horario,
    required this.bio,
    this.afinidad = 0,
  });

  // Calcular edad automáticamente
  int get edad {
    final ahora = DateTime.now();
    int edad = ahora.year - fechaNacimiento.year;
    if (ahora.month < fechaNacimiento.month || 
        (ahora.month == fechaNacimiento.month && ahora.day < fechaNacimiento.day)) {
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
      'esFumador': esFumador,
      'tieneMascotas': tieneMascotas,
      'horario': horario,
      'bio': bio,
    };
  }

  // Crear desde Firebase
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      email: data['email'] ?? '',
      fotoPerfil: data['fotoPerfil'] ?? '',
      fechaNacimiento: (data['fechaNacimiento'] as Timestamp).toDate(),
      genero: data['genero'] ?? '',
      origen: data['origen'] ?? '',
      esFumador: data['esFumador'] ?? false,
      tieneMascotas: data['tieneMascotas'] ?? false,
      horario: data['horario'] ?? '',
      bio: data['bio'] ?? '',
    );
  }
}