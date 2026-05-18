import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ImgbbService {
  /// ImgbbService: irudiak Imgbb API batera igo eta zuzenean eskuragarri dauden URL-ak itzultzen ditu.
  ///
  /// Oharrak: API key publikoa hemen aurkitzen da; produktuan kudeaketa seguruagoa gomendatzen da.
  static const String _apiKey = '610a03435040a53a910ade1fef37391f';
  static final Uri _endpoint = Uri.parse('https://api.imgbb.com/1/upload');

  /// Irudi fitxategi bat jaso eta Imgbb-ra igotzen du, gero URL zuzena bueltatzen du.
  ///
  /// Parametroak: `imageFile` — igotzeko fitxategia.
  /// Itzulera: `Future<String>` — argazkiaren zuzenean erabil daitekeen URL.
  static Future<String> subirImagen(File imageFile) async {
    // Fitxategia bytes bihurtu eta Base64an encode egin, Imgbb APIak hala eskatzen duelako.
    final bytes = await imageFile.readAsBytes();
    final imageBase64 = base64Encode(bytes);

    // POST eskaera bidali Imgbb endpoint-era
    final response = await http.post(
      _endpoint,
      body: <String, String>{'key': _apiKey, 'image': imageBase64},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('ImgBB respondio con codigo ${response.statusCode}');
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Respuesta de ImgBB invalida');
    }

    final directUrl = (data['display_url'] ?? data['url']) as String?;
    if (directUrl == null || directUrl.trim().isEmpty) {
      throw Exception('No se pudo obtener la URL de ImgBB');
    }

    return directUrl;
  }
}
