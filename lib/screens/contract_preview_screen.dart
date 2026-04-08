import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/pdf_service.dart';

class ContractPreviewScreen extends StatefulWidget {
  const ContractPreviewScreen({
    super.key,
    required this.chatId,
    required this.uidParteA,
    required this.uidParteB,
    required this.nombreParteA,
    required this.dniParteA,
    required this.nombreParteB,
    required this.dniParteB,
    required this.direccionInmueble,
    required this.rentaMensual,
    required this.reglasPacto,
    this.idCasa,
  });

  final String chatId;
  final String uidParteA;
  final String uidParteB;
  final String nombreParteA;
  final String dniParteA;
  final String nombreParteB;
  final String dniParteB;
  final String direccionInmueble;
  final double rentaMensual;
  final List<String> reglasPacto;
  final String? idCasa;

  @override
  State<ContractPreviewScreen> createState() => _ContractPreviewScreenState();
}

class _ContractPreviewScreenState extends State<ContractPreviewScreen> {
  final PdfService _pdfService = PdfService.instance;
  late final Future<Uint8List> _pdfFuture;

  @override
  void initState() {
    super.initState();
    _pdfFuture = _buildAndPersistPdf();
  }

  Future<Uint8List> _buildAndPersistPdf() async {
    final bytes = await _pdfService.generarContratoPDF(
      nombreParteA: widget.nombreParteA,
      dniParteA: widget.dniParteA,
      nombreParteB: widget.nombreParteB,
      dniParteB: widget.dniParteB,
      direccionInmueble: widget.direccionInmueble,
      rentaMensual: widget.rentaMensual,
      reglasPacto: widget.reglasPacto,
      fechaGeneracion: DateTime.now(),
    );

    await _pdfService.guardarReferenciaContrato(
      pdfBytes: bytes,
      chatId: widget.chatId,
      uidParteA: widget.uidParteA,
      uidParteB: widget.uidParteB,
      nombreParteA: widget.nombreParteA,
      nombreParteB: widget.nombreParteB,
      dniParteA: widget.dniParteA,
      dniParteB: widget.dniParteB,
      direccionInmueble: widget.direccionInmueble,
      rentaMensual: widget.rentaMensual,
      reglasPacto: widget.reglasPacto,
      idCasa: widget.idCasa,
    );

    return bytes;
  }

  Future<void> _sharePdf() async {
    final bytes = await _pdfFuture;
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'contrato_bizimatch_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contrato Oficial'),
        actions: [
          IconButton(
            onPressed: _sharePdf,
            icon: const Icon(Icons.share),
            tooltip: 'Compartir PDF',
          ),
        ],
      ),
      body: PdfPreview(
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName:
            'contrato_bizimatch_${DateTime.now().millisecondsSinceEpoch}.pdf',
        build: (format) => _pdfFuture,
      ),
    );
  }
}
