import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'demo_service.dart';

/// PdfService: kontratuak PDF formatuan sortu, gordetu eta ireki egiten ditu.
///
/// Zer egiten duen:
/// - PDF bat eraiki `pdf` paketearekin eta Firebase Storage-era igo edo lokalki gorde demo moduan.
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
    final fontBase = pw.Font.times();
    final fontBold = pw.Font.timesBold();

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
    final ts = now.millisecondsSinceEpoch;

    // Demo moduan gauzak lokalki gordetzen ditugu eta irekitzen ditugu
    if (DemoService.instance.isDemoMode.value) {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/contrato_bizimatch_demo_$ts.pdf');
      await file.writeAsBytes(pdfBytes, flush: true);
      await OpenFilex.open(file.path);

      return {
        'pdf_url': file.path,
        'storage_path': file.path,
        'chat_id': chatId,
        'id_casa': idCasa,
        'generado_en': now.toIso8601String(),
        'demo_local': true,
      };
    }

    // Produktzioan Firebase Storage erabili eta kontratua Firestore-en erreferentziatu.
    final path = 'contratos/$chatId/contrato_$ts.pdf';

    final ref = _storage.ref().child(path);
    final uploadTask = await ref.putData(
      pdfBytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'chatId': chatId,
          'uidParteA': uidParteA,
          'uidParteB': uidParteB,
        },
      ),
    );

    final url = await uploadTask.ref.getDownloadURL();

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
      'storage_path': path,
      'pdf_url': url,
      'generado_en': Timestamp.fromDate(now),
      'actualizado_en': FieldValue.serverTimestamp(),
    };

    final contratoDoc = _firestore.collection('contratos').doc(chatId);
    await contratoDoc.set(data, SetOptions(merge: true));
    await contratoDoc.collection('versiones').add(data);

    if (idCasa != null && idCasa.trim().isNotEmpty) {
      final casaDoc = _firestore.collection('casas').doc(idCasa);
      await casaDoc.set({
        'contrato_actual_chat_id': chatId,
        'contrato_actual_url': url,
        'contrato_actualizado_en': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await casaDoc.collection('contratos').doc(chatId).set({
        'chat_id': chatId,
        'pdf_url': url,
        'storage_path': path,
        'generado_en': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    }

    return {
      'pdf_url': url,
      'storage_path': path,
      'chat_id': chatId,
      'id_casa': idCasa,
      'generado_en': now.toIso8601String(),
    };
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
