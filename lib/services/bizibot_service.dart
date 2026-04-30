import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

/// Servicio BiziBot: Genera frases de apertura inteligentes basadas en perfiles
class BiziBotService {
  BiziBotService._privateConstructor();
  static final BiziBotService _instance = BiziBotService._privateConstructor();
  static BiziBotService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mapa de palabras clave y sus frases relacionadas
  static const Map<String, List<String>> _keywordPhrases = {
    'cocina': [
      '¿Practicas alguna receta especial? Me encanta cocinar',
      'Veo que te gusta cocinar, ¿preparas algo con lo que brillas?',
      'Cocinemos juntos alguna noche y compartimos nuestras especialidades',
    ],
    'viajar': [
      '¿Cual ha sido tu viaje mas memorable?',
      'Me encanta explorar nuevos lugares, ¿donde te gustaría ir?',
      'Somos aventureros, ¿cual es tu destino soñado?',
    ],
    'deportes': [
      '¿Que deporte te apasiona mas?',
      'Veo que eres activo, ¿te animas a entrenar juntos?',
      'Un dia de deportes podria ser epico contigo',
    ],
    'musica': [
      '¿Que genero musical te hace feliz?',
      'Me encanta la musica, ¿compartimos nuestras playlists?',
      'Un concierto contigo suena perfecto',
    ],
    'arte': [
      '¿Tienes un artista favorito?',
      'El arte tiene un poder especial, ¿cual es tu favorito?',
      'Podriamos explorar una galeria juntos',
    ],
    'lectura': [
      '¿Cual es el ultimo libro que te fascino?',
      'Los lectores somos gente especial, ¿que leemos?',
      'Recomendame un libro que te haya marked',
    ],
    'cine': [
      '¿Genero de pelicula favorito?',
      'La proxima noche de cine contigo seria genial',
      'Tenemos que ver esa pelicula juntos',
    ],
    'perros': [
      'Me encantan los perros, ¿como es el tuyo?',
      'Los amantes de perros somos especiales',
      'Llevemos a nuestras mascotas a pasear juntos',
    ],
    'gatos': [
      'Los amantes de gatos tienen buen gusto',
      '¿Como se llama tu gato?',
      'Gato lover encontrado',
    ],
    'naturaleza': [
      '¿Cual es tu lugar favorito en la naturaleza?',
      'Las caminatas por la naturaleza son terapeuticas, ¿vamos?',
      'La naturaleza nos acerca',
    ],
    'fotografia': [
      'Tu fotografia parece profesional, ¿haces fotos?',
      'Me encanta capturar momentos, ¿fotografiamos juntos?',
      'Tus fotos son incrementibles',
    ],
    'yoga': [
      '¿Practica yoga contribuye a tu tranquilidad?',
      'El mindfulness y yoga son mi pasion, ¿la tuya?',
      'Una sesion de yoga juntos nos haria bien',
    ],
    'fiesta': [
      '¿Donde encuentras las mejores fiestas?',
      'Estas listo para una noche epica juntos?',
      'Promete ser una grandes noche contigo',
    ],
  };

  /// Frases genéricas fallback
  static const List<String> _fallbackPhrases = [
    'Hola, me gustan mucho tus intereses, ¿hablamos sobre ellos?',
    'He visto tu perfil y creo que podriamos conectar bien',
    '¿Cual es lo que mas te apasiona en la vida?',
    'Me encanta tu energia, ¿cual es tu historia?',
    'Veo que tienes buen gusto, somos compatibles',
    'Tu perfil me intriga, cuéntame mas de ti',
    'Tus intereses me fascinan, ¿tenemos puntos en comun?',
    'Esta sera una gran amistad, lo siento',
    'Me das buenas vibraciones desde el primer perfil',
    'Apostar por nosotros podria ser increible',
  ];

  /// Obtiene el perfil del usuario y genera sugerencias
  Future<List<String>> generarSugerencias(String otherUid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(otherUid).get();
      if (!doc.exists) {
        return _getRandomPhrases(_fallbackPhrases, 3);
      }

      final data = doc.data();
      if (data == null) {
        return _getRandomPhrases(_fallbackPhrases, 3);
      }

      final bio = (data['bio'] as String?) ?? '';
      final intereses = (data['intereses'] as List<dynamic>?) ?? [];
      final profile = _parseUserProfile(data);

      return _generateSuggestions(bio, intereses, profile);
    } catch (e) {
      print('Error en BiziBot: $e');
      return _getRandomPhrases(_fallbackPhrases, 3);
    }
  }

  /// Genera sugerencias basadas en bio, intereses y perfil
  List<String> _generateSuggestions(
    String bio,
    List<dynamic> intereses,
    UserProfile profile,
  ) {
    final suggestions = <String>{};
    final searchText = '$bio ${intereses.join(" ")} ${profile.nombre}'
        .toLowerCase();

    // Buscar palabras clave en la bio e intereses
    for (final entry in _keywordPhrases.entries) {
      if (searchText.contains(entry.key)) {
        suggestions.addAll(entry.value);
        if (suggestions.length >= 3) break;
      }
    }

    // Si no hay suficientes sugerencias, añadir las genéricas
    if (suggestions.length < 3) {
      suggestions.addAll(_fallbackPhrases);
    }

    return _getRandomPhrases(suggestions.toList(), 3);
  }

  /// Obtiene N frases aleatorias de una lista
  List<String> _getRandomPhrases(List<String> phrases, int count) {
    final random = <String>[];
    final available = List<String>.from(phrases);

    for (int i = 0; i < count && available.isNotEmpty; i++) {
      available.shuffle();
      random.add(available.removeAt(0));
    }

    // Si hay menos frases de las solicitadas, completar con fallbacks
    while (random.length < count) {
      _fallbackPhrases.shuffle();
      random.add(_fallbackPhrases[0]);
    }

    return random;
  }

  /// Parsea un mapa a UserProfile
  UserProfile _parseUserProfile(Map<String, dynamic> data) {
    try {
      return UserProfile(
        uid: data['uid'] as String? ?? '',
        email: data['email'] as String? ?? '',
        nombre: data['nombre'] as String? ?? 'Usuario',
        fechaNacimiento: _parseDate(data['fechaNacimiento']),
        genero: data['genero'] as String? ?? '',
        origen: data['origen'] as String? ?? '',
        estudios: data['estudios'] as String? ?? '',
        fumador: data['fumador'] as bool? ?? false,
        mascotas: data['mascotas'] as bool? ?? false,
        tienePiso: data['tienePiso'] as bool? ?? false,
        precioAlquilerPorPersona: data['precioAlquilerPorPersona'] as int?,
        horario: data['horario'] as String? ?? '',
        teletrabajo: data['teletrabajo'] as bool? ?? false,
        frecuenciaFiestas: data['frecuenciaFiestas'] as String? ?? '',
        nivelLimpieza: data['nivelLimpieza'] as String? ?? '',
        bio: data['bio'] as String? ?? '',
        fotoPerfil: data['fotoPerfil'] as String? ?? '',
        intereses: List<String>.from(
          (data['intereses'] as List<dynamic>?) ?? [],
        ),
        lugarDeseado: data['lugarDeseado'] as String? ?? '',
        direccionZona: data['direccionZona'] as String? ?? '',
        fotosPiso: List<String>.from(
          (data['fotosPiso'] as List<dynamic>?) ?? [],
        ),
        voiceBioUrl: data['voiceBioUrl'] as String?,
        karma: (data['karma'] as num?)?.toDouble(),
        biziPuntos: data['biziPuntos'] as int?,
        rachaDias: data['rachaDias'] as int?,
        comodinRachaDisponible: data['comodinRachaDisponible'] as bool?,
        semanasPerfectas: data['semanasPerfectas'] as int?,
        totalResenas: data['totalResenas'] as int?,
        medallasResumen: Map<String, int>.from(
          (data['medallasResumen'] as Map<dynamic, dynamic>?) ?? {},
        ),
      );
    } catch (e) {
      print('Error parsing UserProfile: $e');
      rethrow;
    }
  }

  /// Parsea fecha desde Timestamp
  DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime(2000);
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    return DateTime(2000);
  }
}
