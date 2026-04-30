import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pact_model.dart';
import '../screens/contract_preview_screen.dart';
import '../services/pact_service.dart';

class CoexistencePactScreen extends StatefulWidget {
  const CoexistencePactScreen({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherName,
  });

  final String chatId;
  final String otherUid;
  final String otherName;

  @override
  State<CoexistencePactScreen> createState() => _CoexistencePactScreenState();
}

class _CoexistencePactScreenState extends State<CoexistencePactScreen> {
  final PactService _pactService = PactService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _reglaController = TextEditingController();
  late final String _myUid;
  bool _isSigning = false;
  bool _isGeneratingContract = false;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  void dispose() {
    _reglaController.dispose();
    super.dispose();
  }

  Future<void> _agregarReglasPersonalizadas(String chatId) async {
    final regla = _reglaController.text.trim();
    if (regla.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, escribe una regla')),
      );
      return;
    }

    try {
      await _pactService.agregarReglaPersonalizada(chatId, regla);
      _reglaController.clear();
      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Regla agregada ✓')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _firmarPacto(String chatId) async {
    HapticFeedback.mediumImpact();
    setState(() => _isSigning = true);

    try {
      await _pactService.firmarPacto(chatId, _myUid);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¡Pacto firmado! ✓')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al firmar: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSigning = false);
      }
    }
  }

  Future<void> _abrirGeneradorContrato(Pact pact) async {
    setState(() => _isGeneratingContract = true);
    HapticFeedback.lightImpact();

    try {
      final myDoc = await _firestore.collection('usuarios').doc(_myUid).get();
      final otherDoc = await _firestore
          .collection('usuarios')
          .doc(widget.otherUid)
          .get();

      final myData = myDoc.data() ?? <String, dynamic>{};
      final otherData = otherDoc.data() ?? <String, dynamic>{};

      final nombreA = (myData['nombre'] as String?)?.trim();
      final nombreB = (otherData['nombre'] as String?)?.trim();

      final dniA = (myData['dni'] as String?)?.trim();
      final dniB = (otherData['dni'] as String?)?.trim();

      final direccion =
          ((myData['direccionZona'] as String?)?.trim().isNotEmpty == true
                  ? myData['direccionZona']
                  : otherData['direccionZona'])
              as String?;

      final precioRaw =
          myData['precioAlquilerPorPersona'] ??
          otherData['precioAlquilerPorPersona'] ??
          0;
      final idCasa =
          (myData['id_casa'] as String?) ?? (otherData['id_casa'] as String?);

      final precio = (precioRaw as num).toDouble();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ContractPreviewScreen(
            chatId: widget.chatId,
            uidParteA: _myUid,
            uidParteB: widget.otherUid,
            nombreParteA: (nombreA != null && nombreA.isNotEmpty)
                ? nombreA
                : 'Usuario A',
            dniParteA: (dniA != null && dniA.isNotEmpty)
                ? dniA
                : _simularDni(_myUid),
            nombreParteB: (nombreB != null && nombreB.isNotEmpty)
                ? nombreB
                : widget.otherName,
            dniParteB: (dniB != null && dniB.isNotEmpty)
                ? dniB
                : _simularDni(widget.otherUid),
            direccionInmueble:
                (direccion != null && direccion.trim().isNotEmpty)
                ? direccion
                : 'Direccion pendiente de confirmar',
            rentaMensual: precio,
            reglasPacto: pact.reglas.map((r) => r.titulo).toList(),
            idCasa: idCasa,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el contrato: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingContract = false);
      }
    }
  }

  String _simularDni(String uid) {
    final seed = uid.hashCode.abs().toString().padLeft(8, '0').substring(0, 8);
    return '$seed-Z';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<Pact>(
      stream: _pactService.getPactStream(widget.chatId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pacto de Convivencia')),
            body: const Center(child: Text('Error al cargar el pacto')),
          );
        }

        final pact = snapshot.data!;
        final yaFirme = pact.estadoFirmas[_myUid] ?? false;
        final otroFirmo = pact.estadoFirmas[widget.otherUid] ?? false;
        final estaCerrado = pact.estaCerrado;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pacto de Convivencia'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Cabecera con estado
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F4EE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (estaCerrado)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF10B981),
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '¡Pacto sellado! 🏠',
                                style: textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        else if (yaFirme && !otroFirmo)
                          Column(
                            children: [
                              const Icon(
                                Icons.hourglass_bottom,
                                color: Color(0xFF10B981),
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Esperando a ${widget.otherName}...',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          )
                        else if (otroFirmo && !yaFirme)
                          Column(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF10B981),
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${widget.otherName} ya ha firmado ✅',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              const Icon(
                                Icons.edit_document,
                                color: Color(0xFF10B981),
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ambos deben revisar y firmar',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                // Lista de reglas
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: pact.reglas.length + 1,
                    itemBuilder: (context, index) {
                      if (index == pact.reglas.length) {
                        // Campo para agregar nueva regla
                        if (!estaCerrado) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _reglaController,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Añade una regla personalizada',
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        maxLength: 50,
                                        buildCounter:
                                            (
                                              context, {
                                              required currentLength,
                                              required isFocused,
                                              required maxLength,
                                            }) => null,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add,
                                        color: Color(0xFF10B981),
                                      ),
                                      onPressed: () =>
                                          _agregarReglasPersonalizadas(
                                            widget.chatId,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }

                      final regla = pact.reglas[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: CheckboxListTile(
                            title: Text(regla.titulo),
                            value: regla.completado,
                            onChanged: estaCerrado
                                ? null
                                : (valor) {
                                    HapticFeedback.selectionClick();
                                    final reglaActualizada = regla.copyWith(
                                      completado: valor ?? false,
                                    );
                                    _pactService.actualizarRegla(
                                      widget.chatId,
                                      index,
                                      reglaActualizada,
                                    );
                                  },
                            activeColor: const Color(0xFF10B981),
                            checkColor: Colors.white,
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            secondary: estaCerrado && regla.completado
                                ? const Icon(
                                    Icons.lock,
                                    color: Color(0xFF10B981),
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Botón Firmar Pacto / Contrato Oficial
                if (!estaCerrado)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: !yaFirme
                        ? SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSigning
                                  ? null
                                  : () => _firmarPacto(widget.chatId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                disabledBackgroundColor: Colors.grey[300],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSigning
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Firmar Pacto',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F4EE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pacto Firmado ✓',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                if (estaCerrado)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingContract
                            ? null
                            : () => _abrirGeneradorContrato(pact),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          disabledBackgroundColor: Colors.grey[300],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isGeneratingContract
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf),
                        label: Text(
                          _isGeneratingContract
                              ? 'Generando contrato...'
                              : 'Generar Contrato Oficial',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
