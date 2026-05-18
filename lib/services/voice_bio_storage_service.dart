import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class VoiceBioStorageService {
  /// VoiceBioStorageService: erabiltzailearen 'voice bio' audio fitxategien biltegiratzea kudeatzen du.
  ///
  /// Zer egiten duen:
  /// - Local fitxategiak Firebase Storage-era igo edo tokian bertan ezabatzen ditu demo moduan.
  VoiceBioStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Audio fitxategi lokal bat igo eta gero URL publikoa bueltatzen du.
  Future<String> uploadVoiceBio({
    required String uid,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('Archivo de audio no encontrado.');
    }

    // Firebase Storage-eko path dinamikoa sortu, timestamparekin.
    final ref = _storage
        .ref()
        .child('voice_bios')
        .child(uid)
        .child('voice_${DateTime.now().millisecondsSinceEpoch}.m4a');

    await ref.putFile(file, SettableMetadata(contentType: 'audio/mp4'));

    return ref.getDownloadURL();
  }

  /// Ezabatu audioa lokaleko path edo URL emanda.
  /// - URL bada, Storage-etik ezabatzen du; bestela fitxategi lokala ezabatzen saiatzen da.
  Future<void> deleteVoiceBioByPathOrUrl(String pathOrUrl) async {
    final value = pathOrUrl.trim();
    if (value.isEmpty) {
      return;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      final ref = _storage.refFromURL(value);
      await ref.delete();
      return;
    }

    final file = File(value);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
