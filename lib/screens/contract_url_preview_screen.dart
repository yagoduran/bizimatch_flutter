import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

class ContractUrlPreviewScreen extends StatelessWidget {
  const ContractUrlPreviewScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  final String pdfUrl;
  final String title;

  Future<Uint8List> _downloadPdf() async {
    final response = await http.get(Uri.parse(pdfUrl));
    if (response.statusCode != 200) {
      throw Exception('No se pudo descargar el contrato.');
    }
    return response.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        build: (format) => _downloadPdf(),
      ),
    );
  }
}
