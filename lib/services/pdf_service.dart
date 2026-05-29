import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ContractPdfResult {
  const ContractPdfResult({
    required this.pdfBytes,
    required this.localFile,
    required this.contractUrl,
    required this.storagePath,
  });

  final Uint8List pdfBytes;
  final File localFile;
  final String contractUrl;
  final String storagePath;
}

/// PdfService: kontratuak PDF formatuan sortu, gordetu eta ireki egiten ditu.
///
/// Zer egiten duen:
  /// - PDF bat eraiki `pdf` paketearekin eta Firebase Storage-era igo.
class PdfService {
  PdfService._internal();
  static final PdfService instance = PdfService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Uint8List> generarContratoPDF({
    required String nombreParteA,
    required String dniParteA,
    required String nombreParteB,
    required String dniParteB,
    required String direccionInmueble,
    required double rentaMensual,
    required List<String> reglasPacto,
    required DateTime fechaGeneracion,
  }) async {
    // PDF dokumentuaren eraikuntza: style eta orri konfigurazioa prestatu.
    final documento = pw.Document();
    final fontBase = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 44),
        theme: pw.ThemeData.withFont(base: fontBase, bold: fontBold),
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'BiziMatch - Documento privado',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Pagina ${context.pageNumber} de ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            _buildHeader(fontBold),
            pw.SizedBox(height: 18),
            pw.Center(
              child: pw.Text(
                'CONTRATO DE CONVIVENCIA Y SUBARRIENDO',
                style: pw.TextStyle(font: fontBold, fontSize: 14),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 20),
            _buildParrafo(
              'En fecha ${_formatearFecha(fechaGeneracion)}, las partes abajo identificadas acuerdan formalizar el presente contrato de convivencia y subarriendo, conforme a las siguientes clausulas:',
            ),
            pw.SizedBox(height: 12),
            _buildClausula(
              numero: 'I',
              titulo: 'Identificacion de las partes',
              contenido:
                  'Primera parte: $nombreParteA, DNI $dniParteA.\nSegunda parte: $nombreParteB, DNI $dniParteB.',
              fontBold: fontBold,
            ),
            _buildClausula(
              numero: 'II',
              titulo: 'Objeto del contrato',
              contenido:
                  'El presente contrato regula la convivencia y uso compartido del inmueble ubicado en $direccionInmueble, destinandose exclusivamente a vivienda habitual de las partes firmantes.',
              fontBold: fontBold,
            ),
            _buildClausula(
              numero: 'III',
              titulo: 'Renta y gastos',
              contenido:
                  'La renta mensual pactada asciende a EUR ${rentaMensual.toStringAsFixed(2)} por persona, sin perjuicio del reparto adicional de suministros y gastos comunes que ambas partes acuerden por escrito.',
              fontBold: fontBold,
            ),
            _buildClausula(
              numero: 'IV',
              titulo: 'Reglas de convivencia (Pacto BiziMatch)',
              contenido: reglasPacto.isEmpty
                  ? 'Las partes se comprometen a mantener normas basicas de respeto, limpieza y convivencia pacifica.'
                  : reglasPacto
                        .asMap()
                        .entries
                        .map((entry) => '${entry.key + 1}. ${entry.value}')
                        .join('\n'),
              fontBold: fontBold,
            ),
            _buildClausula(
              numero: 'V',
              titulo: 'Vigencia y aceptacion',
              contenido:
                  'El presente acuerdo entra en vigor en la fecha de su generacion digital y se mantendra vigente mientras ambas partes compartan vivienda, salvo resolucion por mutuo acuerdo o incumplimiento grave.',
              fontBold: fontBold,
            ),
            pw.SizedBox(height: 28),
            _buildFirmas(nombreParteA, nombreParteB, fechaGeneracion, fontBold),
          ];
        },
      ),
    );

    return documento.save();
  }

  Future<ContractPdfResult> generarYGuardarContrato({
    required String chatId,
    required String uidParteA,
    required String uidParteB,
    required String nombreParteA,
    required String nombreParteB,
    required String dniParteA,
    required String dniParteB,
    required String direccionInmueble,
    required double rentaMensual,
    required List<String> reglasPacto,
    required DateTime fechaGeneracion,
    String? idCasa,
  }) async {
    final pdfBytes = await generarContratoPDF(
      nombreParteA: nombreParteA,
      dniParteA: dniParteA,
      nombreParteB: nombreParteB,
      dniParteB: dniParteB,
      direccionInmueble: direccionInmueble,
      rentaMensual: rentaMensual,
      reglasPacto: reglasPacto,
      fechaGeneracion: fechaGeneracion,
    );

    final result = await guardarReferenciaContrato(
      pdfBytes: pdfBytes,
      chatId: chatId,
      uidParteA: uidParteA,
      uidParteB: uidParteB,
      nombreParteA: nombreParteA,
      nombreParteB: nombreParteB,
      dniParteA: dniParteA,
      dniParteB: dniParteB,
      direccionInmueble: direccionInmueble,
      rentaMensual: rentaMensual,
      reglasPacto: reglasPacto,
      idCasa: idCasa,
    );

    return ContractPdfResult(
      pdfBytes: pdfBytes,
      localFile: File(result['local_file_path'] as String),
      contractUrl: (result['contractUrl'] as String?) ??
          (result['pdf_url'] as String? ?? ''),
      storagePath: (result['storage_path'] as String?) ?? '',
    );
  }

  Future<Map<String, dynamic>> guardarReferenciaContrato({
    required Uint8List pdfBytes,
    required String chatId,
    required String uidParteA,
    required String uidParteB,
    required String nombreParteA,
    required String nombreParteB,
    required String dniParteA,
    required String dniParteB,
    required String direccionInmueble,
    required double rentaMensual,
    required List<String> reglasPacto,
    String? idCasa,
  }) async {
    final now = DateTime.now();
    final agreementId = chatId.trim();
    final storagePath = 'contracts/elkarbizitza_ituna_$agreementId.pdf';
    final localFile = await _writePdfToTempFile(
      pdfBytes: pdfBytes,
      agreementId: agreementId,
    );

    final ref = _storage.ref().child(storagePath);

    String downloadUrl;
    try {
      final uploadTask = await ref.putFile(
        localFile,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'chatId': chatId,
            'uidParteA': uidParteA,
            'uidParteB': uidParteB,
            'agreementId': agreementId,
          },
        ),
      );
      downloadUrl = await uploadTask.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception(
        'No se pudo subir el contrato a Firebase Storage: ${e.message ?? e.code}',
      );
    }

    final data = <String, dynamic>{
      'chat_id': chatId,
      'id_casa': idCasa,
      'uid_parte_a': uidParteA,
      'uid_parte_b': uidParteB,
      'nombre_parte_a': nombreParteA,
      'nombre_parte_b': nombreParteB,
      'dni_parte_a': dniParteA,
      'dni_parte_b': dniParteB,
      'direccion_inmueble': direccionInmueble,
      'renta_mensual': rentaMensual,
      'reglas_pacto': reglasPacto,
      'storage_path': storagePath,
      'contractUrl': downloadUrl,
      'pdf_url': downloadUrl,
      'generated_at': Timestamp.fromDate(now),
      'generado_en': Timestamp.fromDate(now),
      'actualizado_en': FieldValue.serverTimestamp(),
    };

    try {
      final contratoDoc = _firestore.collection('contratos').doc(chatId);
      await contratoDoc.set(data, SetOptions(merge: true));
      await contratoDoc.collection('versiones').add(data);

      if (idCasa != null && idCasa.trim().isNotEmpty) {
        final casaDoc = _firestore.collection('casas').doc(idCasa);
        await casaDoc.set({
          'contrato_actual_chat_id': chatId,
          'contrato_actual_url': downloadUrl,
          'contractUrl': downloadUrl,
          'contrato_actualizado_en': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await casaDoc.collection('contratos').doc(chatId).set({
          'chat_id': chatId,
          'pdf_url': downloadUrl,
          'contractUrl': downloadUrl,
          'storage_path': storagePath,
          'generated_at': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      }
    } on FirebaseException catch (e) {
      throw Exception(
        'No se pudo actualizar Firestore con el contrato: ${e.message ?? e.code}',
      );
    }

    return {
      'contractUrl': downloadUrl,
      'pdf_url': downloadUrl,
      'storage_path': storagePath,
      'local_file_path': localFile.path,
      'chat_id': chatId,
      'id_casa': idCasa,
      'generado_en': now.toIso8601String(),
    };
  }

  Future<File> _writePdfToTempFile({
    required Uint8List pdfBytes,
    required String agreementId,
  }) async {
    final directory = await getTemporaryDirectory();
    final contractsDir = Directory('${directory.path}/contracts');
    if (!await contractsDir.exists()) {
      await contractsDir.create(recursive: true);
    }

    final file = File(
      '${contractsDir.path}/elkarbizitza_ituna_$agreementId.pdf',
    );
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }

  pw.Widget _buildHeader(pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.green600, width: 1),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'BiziMatch',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 13,
                  color: PdfColors.green700,
                ),
              ),
            ),
            pw.Text(
              'Documento contractual',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(height: 2, color: PdfColors.green600),
      ],
    );
  }

  pw.Widget _buildParrafo(String texto) {
    return pw.Text(
      texto,
      style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
      textAlign: pw.TextAlign.justify,
    );
  }

  pw.Widget _buildClausula({
    required String numero,
    required String titulo,
    required String contenido,
    required pw.Font fontBold,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CLAUSULA $numero. $titulo',
            style: pw.TextStyle(font: fontBold, fontSize: 12),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            contenido,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFirmas(
    String nombreParteA,
    String nombreParteB,
    DateTime fechaGeneracion,
    pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Firmas Digitales',
          style: pw.TextStyle(font: fontBold, fontSize: 12),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: _buildFirmaBox(nombreParteA, fechaGeneracion, fontBold),
            ),
            pw.SizedBox(width: 18),
            pw.Expanded(
              child: _buildFirmaBox(nombreParteB, fechaGeneracion, fontBold),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFirmaBox(String nombre, DateTime fecha, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 1, color: PdfColors.grey600),
        pw.SizedBox(height: 4),
        pw.Text(nombre, style: pw.TextStyle(font: fontBold, fontSize: 11)),
        pw.Text(
          'Fecha: ${_formatearFecha(fecha)}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    );
  }

  String _formatearFecha(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}
