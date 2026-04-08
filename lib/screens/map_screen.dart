import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/user_profile.dart';
import '../widgets/app_cached_network_image.dart';
import 'profile_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late MapController _mapController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _markersSub;
  List<UserProfile> _usersWithPiso = [];
  UserProfile? _selectedUser;

  // Posición inicial (Madrid, España)
  static const LatLng _initialPosition = LatLng(40.4168, -3.7038);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadMarkersFromFirestore();
  }

  void _loadMarkersFromFirestore() {
    _markersSub?.cancel();
    _markersSub = _firestore
        .collection('usuarios')
        .where('tienePiso', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) {
            final users = <UserProfile>[];
            for (final doc in snapshot.docs) {
              try {
                users.add(UserProfile.fromMap(doc.data()));
              } catch (e) {
                debugPrint('Error al procesar usuario: $e');
              }
            }
            if (mounted) {
              setState(() {
                _usersWithPiso = users;
              });
            }
          },
          onError: (error) {
            debugPrint('Error cargando marcadores: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sin conexión. No se pueden cargar los pisos.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          },
        );
  }

  LatLng _getSimulatedPosition(String uid) {
    // Hash simple para generar coordenadas diferentes por UID
    final hashCode = uid.hashCode;
    final lat = 40.4168 + ((hashCode % 100) / 1000);
    final lng = -3.7038 + ((hashCode % 100) / 1000);
    return LatLng(lat, lng);
  }

  String _heroTagForUser(String uid) => 'profile-photo-$uid';

  void _selectUser(UserProfile user) {
    setState(() {
      _selectedUser = user;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mapa de Pisos Disponibles',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Stack(
        children: [
          // FlutterMap con CartoDB Positron
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 13.5,
              onTap: (tapPosition, latLng) => _clearSelection(),
            ),
            children: [
              // TileLayer - CartoDB Positron (limpio y minimalista)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.bizimatch.app',
              ),
              // Marcadores personalizados (gotas de agua)
              MarkerLayer(
                markers: _usersWithPiso.map((user) {
                  final position = _getSimulatedPosition(user.uid);
                  final isSelected = _selectedUser?.uid == user.uid;
                  return Marker(
                    point: position,
                    width: 60,
                    height: 80,
                    child: GestureDetector(
                      onTap: () => _selectUser(user),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Etiqueta de precio flotante
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              '${user.precioAlquilerPorPersona}€',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Gota de agua (pin personalizado)
                          _buildDropPin(isSelected),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // Leyenda flotante
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏠', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'Pines = Piso Disponible',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Ventana flotante con detalles del usuario seleccionado
          if (_selectedUser != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: _buildUserCard(_selectedUser!),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        onPressed: () {
          _mapController.move(_initialPosition, 13.5);
          _clearSelection();
        },
        elevation: 4,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Widget _buildDropPin(bool isSelected) {
    final scale = isSelected ? 1.2 : 1.0;
    return Transform.scale(
      scale: scale,
      child: CustomPaint(
        painter: DropPinPainter(
          color: const Color(0xFF10B981),
          isSelected: isSelected,
        ),
        size: const Size(40, 50),
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con foto y botón cerrar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Foto circular
                Hero(
                  tag: _heroTagForUser(user.uid),
                  child: Material(
                    color: Colors.transparent,
                    child: AppCachedAvatar(
                      imageUrl: user.fotoPerfil,
                      radius: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Nombre, edad y zona
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user.nombre}, ${user.edad}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.lugarDeseado.isNotEmpty
                            ? user.lugarDeseado
                            : user.origen,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Botón cerrar
                GestureDetector(
                  onTap: _clearSelection,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Secciones de info
            Row(
              children: [
                // Precio
                Expanded(
                  child: _infoSection(
                    '💰 Alquiler',
                    '${user.precioAlquilerPorPersona}€/mes',
                  ),
                ),
                const SizedBox(width: 12),
                // Búsqueda
                Expanded(child: _infoSection('🔍 Busca', 'Compañeros')),
              ],
            ),
            const SizedBox(height: 12),
            // Botón Ver Perfil
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileDetailScreen(
                        userUid: user.uid,
                        heroTag: _heroTagForUser(user.uid),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Ver Perfil Completo',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _markersSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}

/// Widget personalizado para dibujar un pin en forma de gota de agua
class DropPinPainter extends CustomPainter {
  final Color color;
  final bool isSelected;

  DropPinPainter({required this.color, this.isSelected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // Dibujar sombra
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.7 + 2),
      12,
      shadowPaint,
    );

    // Dibujar la gota de agua
    final path = ui.Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Crear forma de gota usando más puntos de control
    path.moveTo(centerX, size.height * 0.1); // Punta superior
    path.cubicTo(
      centerX + size.width * 0.24,
      size.height * 0.1,
      centerX + size.width * 0.35,
      size.height * 0.2,
      centerX + size.width * 0.35,
      size.height * 0.35,
    );
    path.cubicTo(
      centerX + size.width * 0.35,
      size.height * 0.5,
      centerX,
      size.height * 0.75,
      centerX,
      size.height * 0.75,
    );
    path.cubicTo(
      centerX,
      size.height * 0.75,
      centerX - size.width * 0.35,
      size.height * 0.5,
      centerX - size.width * 0.35,
      size.height * 0.35,
    );
    path.cubicTo(
      centerX - size.width * 0.35,
      size.height * 0.2,
      centerX - size.width * 0.24,
      size.height * 0.1,
      centerX,
      size.height * 0.1,
    );
    path.close();

    canvas.drawPath(path, paint);

    // Dibujar icono de casa blanco en el centro
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.5;

    // Triángulo del techo
    final roofPath = ui.Path();
    roofPath.moveTo(centerX - 6, centerY + 2);
    roofPath.lineTo(centerX, centerY - 4);
    roofPath.lineTo(centerX + 6, centerY + 2);
    roofPath.close();
    canvas.drawPath(roofPath, iconPaint);

    // Rectángulo de la casa
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY + 6),
        width: 10,
        height: 8,
      ),
      iconPaint,
    );

    // Puerta (pequeño rectángulo)
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY + 8),
        width: 3,
        height: 4,
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // Borde del pin si está seleccionado
    if (isSelected) {
      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(DropPinPainter oldDelegate) =>
      oldDelegate.isSelected != isSelected || oldDelegate.color != color;
}
