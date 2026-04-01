import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/user_profile.dart';
import 'profile_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _markersSub;
  List<UserProfile> _usersWithPiso = [];

  // Posición inicial (Madrid, España)
  static const LatLng _initialPosition = LatLng(40.4168, -3.7038);

  @override
  void initState() {
    super.initState();
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
    // Hash simple para generar coordenadas diferentes por UID (variación desde Madrid)
    final hashCode = uid.hashCode;
    final lat = 40.4168 + ((hashCode % 100) / 1000);
    final lng = -3.7038 + ((hashCode % 100) / 1000);
    return LatLng(lat, lng);
  }

  void _showUserPopup(UserProfile user, LatLng position) {
    // Popup pequeño con Card que muestra nombre, precio, foto
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GestureDetector(
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileDetailScreen(userUid: user.uid),
              ),
            );
          },
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Foto
                  if (user.fotoPerfil.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        user.fotoPerfil,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, size: 60),
                      ),
                    )
                  else
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person, size: 60),
                    ),
                  const SizedBox(height: 12),
                  // Nombre
                  Text(
                    user.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Precio
                  Text(
                    '${user.precioAlquilerPorPersona}€/mes',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Texto para tocar
                  const Text(
                    'Toca para ver perfil',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _initialPosition,
            initialZoom: 12.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bizimatch.app',
            ),
            MarkerLayer(
              markers: _usersWithPiso.map((user) {
                final position = _getSimulatedPosition(user.uid);
                return Marker(
                  point: position,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _showUserPopup(user, position),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.home_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _markersSub?.cancel();
    super.dispose();
  }
}
