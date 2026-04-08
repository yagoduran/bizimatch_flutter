import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'dart:typed_data';

import '../app_theme.dart';
import '../models/casa_model.dart';
import '../models/tarea_model.dart';
import '../models/user_model.dart';
import '../screens/contract_url_preview_screen.dart';
import '../services/home_service.dart';
import '../widgets/app_cached_network_image.dart';

class HomeManagementScreen extends StatefulWidget {
  const HomeManagementScreen({Key? key}) : super(key: key);

  @override
  State<HomeManagementScreen> createState() => _HomeManagementScreenState();
}

class _HomeManagementScreenState extends State<HomeManagementScreen>
    with SingleTickerProviderStateMixin {
  final HomeService _homeService = HomeService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _idCasa;
  late AnimationController _celebrationController;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _loadIdCasa();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _loadIdCasa() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    try {
      final doc = await _firestore.collection('usuarios').doc(myUid).get();
      final data = doc.data() ?? {};
      final idCasa = data['id_casa'] as String?;

      if (mounted) {
        setState(() => _idCasa = idCasa);
      }
    } catch (e) {
      print('Error loading id_casa: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid ?? '';

    if (_idCasa == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mi Casa'),
          backgroundColor: const Color(0xFF10B981),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Aun no tienes casa compartida',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Completa una mudanza para activar Mi Casa',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2FBF7),
      appBar: AppBar(
        title: const Text(
          'Mi Casa',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF10B981),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildContratoVigenteCard(_idCasa!),
            const SizedBox(height: 16),

            // Dashboard de Ranking
            _buildRankingDashboard(_idCasa!, myUid),
            const SizedBox(height: 24),

            // Lista de Tareas
            _buildTareasSection(_idCasa!, myUid),
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCrearTareaDialog(_idCasa!, myUid),
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Tarea'),
      ),
    );
  }

  Widget _buildContratoVigenteCard(String idCasa) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('casas').doc(idCasa).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final url = (data?['contrato_actual_url'] as String?)?.trim() ?? '';
        final chatId = (data?['contrato_actual_chat_id'] as String?) ?? '';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDAEFE5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F4EE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Contrato vigente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                url.isEmpty
                    ? 'Aun no hay contrato oficial generado para esta casa.'
                    : 'Contrato vinculado ${chatId.isEmpty ? '' : '(Chat $chatId)'}',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              if (url.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _verContrato(url),
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('Ver'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _imprimirContrato(url),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Imprimir'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _compartirContrato(url),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Compartir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _verContrato(String url) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ContractUrlPreviewScreen(pdfUrl: url, title: 'Contrato Oficial'),
      ),
    );
  }

  Future<void> _imprimirContrato(String url) async {
    try {
      final bytes = await _downloadPdfBytes(url);
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo imprimir: $e')));
    }
  }

  Future<void> _compartirContrato(String url) async {
    try {
      final bytes = await _downloadPdfBytes(url);
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'contrato_bizimatch_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo compartir: $e')));
    }
  }

  Future<Uint8List> _downloadPdfBytes(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception(
        'Error al descargar el contrato (${response.statusCode})',
      );
    }
    return response.bodyBytes;
  }

  Widget _buildRankingDashboard(String idCasa, String myUid) {
    return StreamBuilder<Map<String, int>>(
      stream: _homeService.getPuntosDelMesStream(idCasa),
      builder: (context, puntosSnapshot) {
        final puntosMap = puntosSnapshot.data ?? {};

        return FutureBuilder<Casa?>(
          future: _homeService.obtenerCasa(idCasa),
          builder: (context, casaSnapshot) {
            final casa = casaSnapshot.data;
            if (casa == null) return SizedBox.shrink();

            return FutureBuilder<List<UserModel>>(
              future: _loadMembers(casa.miembrosIds),
              builder: (context, membersSnapshot) {
                final members = membersSnapshot.data ?? [];
                if (members.isEmpty) return SizedBox.shrink();

                // Ordenar miembros por puntos
                final sortedMembers = List<UserModel>.from(members);
                sortedMembers.sort((a, b) {
                  final puntosA = puntosMap[a.id] ?? 0;
                  final puntosB = puntosMap[b.id] ?? 0;
                  return puntosB.compareTo(puntosA);
                });

                // Top 3 para el podio
                final top3 = sortedMembers.take(3).toList();

                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Compañero del Mes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Podio
                      SizedBox(
                        height: 200,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Segundo lugar (izquierda)
                            if (top3.length > 1)
                              _buildPodiumPosition(
                                member: top3[1],
                                position: 2,
                                puntos: puntosMap[top3[1].id] ?? 0,
                                height: 120,
                              )
                            else
                              SizedBox(width: 80),

                            // Primer lugar (centro)
                            _buildPodiumPosition(
                              member: top3[0],
                              position: 1,
                              puntos: puntosMap[top3[0].id] ?? 0,
                              height: 160,
                            ),

                            // Tercer lugar (derecha)
                            if (top3.length > 2)
                              _buildPodiumPosition(
                                member: top3[2],
                                position: 3,
                                puntos: puntosMap[top3[2].id] ?? 0,
                                height: 100,
                              )
                            else
                              SizedBox(width: 80),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Mi Ranking (donde estoy yo)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Mis Puntos:',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${puntosMap[myUid] ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPodiumPosition({
    required UserModel member,
    required int position,
    required int puntos,
    required double height,
  }) {
    final colors = [Colors.amber, Colors.grey[400], Color(0xFFCD7F32)];
    final bgColor = colors[position - 1]!;

    return Column(
      children: [
        // Medalla/Corona
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Icon(
              position == 1 ? Icons.emoji_events : Icons.star,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Avatar
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: bgColor.withOpacity(0.5), width: 3),
            borderRadius: BorderRadius.circular(30),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: AppCachedNetworkImage(
              imageUrl: member.fotoPerfil,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Podio
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.3),
            border: Border.all(color: bgColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$position',
                style: TextStyle(
                  color: bgColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                member.nombre.split(' ')[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '$puntos pts',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTareasSection(String idCasa, String myUid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tareas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Tarea>>(
            stream: _homeService.getTareasStream(idCasa),
            builder: (context, snapshot) {
              final tareas = snapshot.data ?? [];

              if (tareas.isEmpty) {
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No hay tareas',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Separar completadas y pendientes
              final pendientes = tareas.where((t) => !t.completada).toList();
              final completadas = tareas.where((t) => t.completada).toList();

              return Column(
                children: [
                  if (pendientes.isNotEmpty) ...[
                    const Text(
                      'Pendientes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...pendientes.map(
                      (tarea) => _buildTareaCard(tarea, idCasa, myUid),
                    ),
                  ],
                  if (completadas.isNotEmpty && pendientes.isNotEmpty)
                    const SizedBox(height: 16),
                  if (completadas.isNotEmpty) ...[
                    const Text(
                      'Completadas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...completadas.map(
                      (tarea) => _buildTareaCard(tarea, idCasa, myUid),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTareaCard(Tarea tarea, String idCasa, String myUid) {
    final IconData iconoCategoria = _getIconoCategoria(tarea.categoria);
    final esAsignadoAMi = tarea.asignadoA == myUid;
    final ahora = DateTime.now();
    final diasRestantes = tarea.fechaLimite.difference(ahora).inDays;
    final estaProxima = diasRestantes <= 2 && diasRestantes > 0;
    final estaVencida = diasRestantes < 0 && !tarea.completada;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: tarea.completada
            ? const Color(0xFF10B981).withOpacity(0.1)
            : estaVencida
            ? Colors.red.withOpacity(0.05)
            : estaProxima
            ? Colors.orange.withOpacity(0.05)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: tarea.completada
                ? const Color(0xFF10B981)
                : estaVencida
                ? Colors.red
                : estaProxima
                ? Colors.orange
                : Colors.grey[200] ?? Colors.grey,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: esAsignadoAMi && !tarea.completada
                    ? () => _completarTarea(tarea, idCasa, myUid)
                    : null,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 2,
                    ),
                    color: tarea.completada
                        ? const Color(0xFF10B981)
                        : Colors.transparent,
                  ),
                  child: tarea.completada
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 12),

              // Icono categoría
              Icon(iconoCategoria, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),

              // Info de tarea
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tarea.titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: tarea.completada
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: tarea.completada ? Colors.grey : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (estaVencida)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Vencida',
                              style: TextStyle(fontSize: 10, color: Colors.red),
                            ),
                          )
                        else if (estaProxima)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Proxima vencer',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Puntos
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9F7AEA), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${tarea.puntos}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completarTarea(Tarea tarea, String idCasa, String myUid) async {
    try {
      await _homeService.completarTarea(
        idCasa: idCasa,
        idTarea: tarea.idTarea,
        uidUsuario: myUid,
        puntos: tarea.puntos,
      );

      HapticFeedback.mediumImpact();

      // Animación de celebración
      await _celebrationController.forward();
      await _celebrationController.reverse();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 8),
              Text('+${tarea.puntos} BiziPuntos'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error completando tarea: $e');
    }
  }

  void _showCrearTareaDialog(String idCasa, String myUid) {
    showDialog(
      context: context,
      builder: (context) => _CrearTareaDialog(idCasa: idCasa, myUid: myUid),
    );
  }

  IconData _getIconoCategoria(TareaCategoria cat) {
    switch (cat) {
      case TareaCategoria.limpieza:
        return Icons.cleaning_services;
      case TareaCategoria.compras:
        return Icons.shopping_cart;
      case TareaCategoria.pagos:
        return Icons.payment;
      case TareaCategoria.reparaciones:
        return Icons.build;
      default:
        return Icons.assignment;
    }
  }

  Future<List<UserModel>> _loadMembers(List<String> memberIds) async {
    final members = <UserModel>[];
    for (final uid in memberIds) {
      try {
        final doc = await _firestore.collection('usuarios').doc(uid).get();
        if (doc.exists) {
          members.add(UserModel.fromFirestore(doc.data() ?? {}, id: uid));
        }
      } catch (e) {
        print('Error loading member: $e');
      }
    }
    return members;
  }
}

class _CrearTareaDialog extends StatefulWidget {
  final String idCasa;
  final String myUid;

  const _CrearTareaDialog({required this.idCasa, required this.myUid});

  @override
  State<_CrearTareaDialog> createState() => _CrearTareaDialogState();
}

class _CrearTareaDialogState extends State<_CrearTareaDialog> {
  final HomeService _homeService = HomeService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController _tituloController;
  late TextEditingController _puntosController;
  late TextEditingController _descripcionController;

  TareaCategoria _categoriaSeleccionada = TareaCategoria.limpieza;
  DateTime _fechaLimite = DateTime.now().add(Duration(days: 1));
  String? _asignadoA;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController();
    _puntosController = TextEditingController(text: '10');
    _descripcionController = TextEditingController();
    _asignadoA = widget.myUid;
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _puntosController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Tarea'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Titulo de la tarea',
                hintText: 'Ej: Limpiar baño',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripcion (opcional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            const Text(
              'Categoria:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TareaCategoria.values
                  .map(
                    (cat) => ChoiceChip(
                      label: Text(_categoriaNombre(cat)),
                      selected: _categoriaSeleccionada == cat,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _categoriaSeleccionada = cat);
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _puntosController,
              decoration: const InputDecoration(labelText: 'Puntos (0-100)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            const Text(
              'Fecha limite:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text(
                '${_fechaLimite.day}/${_fechaLimite.month}/${_fechaLimite.year}',
              ),
              onTap: _pickDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<UserModel>>(
              future: _loadMiembros(),
              builder: (context, snapshot) {
                final miembros = snapshot.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asignar a:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...miembros.map(
                      (miembro) => RadioListTile(
                        title: Text(miembro.nombre),
                        value: miembro.id,
                        groupValue: _asignadoA,
                        onChanged: (value) {
                          setState(() => _asignadoA = value);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _crearTarea,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
          ),
          child: const Text('Crear'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaLimite,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _fechaLimite = picked);
    }
  }

  Future<void> _crearTarea() async {
    if (_tituloController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un titulo')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final puntos = int.tryParse(_puntosController.text) ?? 10;

      await _homeService.crearTarea(
        idCasa: widget.idCasa,
        titulo: _tituloController.text,
        puntos: puntos.clamp(0, 100),
        asignadoA: _asignadoA ?? widget.myUid,
        fechaLimite: _fechaLimite,
        descripcion: _descripcionController.text.isEmpty
            ? null
            : _descripcionController.text,
        categoria: _categoriaSeleccionada,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarea creada exitosamente'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      print('Error creando tarea: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _categoriaNombre(TareaCategoria cat) {
    switch (cat) {
      case TareaCategoria.limpieza:
        return 'Limpieza';
      case TareaCategoria.compras:
        return 'Compras';
      case TareaCategoria.pagos:
        return 'Pagos';
      case TareaCategoria.reparaciones:
        return 'Reparaciones';
      default:
        return 'Otro';
    }
  }

  Future<List<UserModel>> _loadMiembros() async {
    try {
      final casa = await _homeService.obtenerCasa(widget.idCasa);
      if (casa == null) return [];

      final miembros = <UserModel>[];
      for (final uid in casa.miembrosIds) {
        try {
          final doc = await _firestore.collection('usuarios').doc(uid).get();
          if (doc.exists) {
            miembros.add(UserModel.fromFirestore(doc.data() ?? {}, id: uid));
          }
        } catch (e) {
          print('Error loading member: $e');
        }
      }
      return miembros;
    } catch (e) {
      print('Error loading miembros: $e');
      return [];
    }
  }
}
