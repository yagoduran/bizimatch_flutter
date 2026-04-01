import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/user_profile.dart';
import 'profile_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Posición inicial (Madrid, España)
  static const LatLng _initialPosition = LatLng(40.4168, -3.7038);

  @override
  void initState() {
    super.initState();
    _loadMarkersFromFirestore();
  }

  void _loadMarkersFromFirestore() {
    _firestore
        .collection('usuarios')
        .where('tienePiso', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) {
            final newMarkers = <Marker>{};

            for (final doc in snapshot.docs) {
              try {
                final userProfile = UserProfile.fromMap(doc.data());
                // En producción, deberías guardar lat/lng en Firestore
                final markerPosition = _getSimulatedPosition(userProfile.uid);

                newMarkers.add(
                  Marker(
                    markerId: MarkerId(userProfile.uid),
                    position: markerPosition,
                    infoWindow: InfoWindow(
                      title: userProfile.nombre,
                      snippet:
                          '${userProfile.precioAlquilerPorPersona}€/mes - Tap para ver perfil',
                      onTap: () => _showUserInfoBottomSheet(userProfile),
                    ),
                    onTap: () => _showUserInfoBottomSheet(userProfile),
                  ),
                );
              } catch (e) {
                debugPrint('Error al procesar usuario: $e');
              }
            }

            if (mounted) {
              setState(() {
                _markers.clear();
                _markers.addAll(newMarkers);
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

  void _showUserInfoBottomSheet(UserProfile user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Avatar
              CircleAvatar(
                radius: 50,
                backgroundImage: user.fotoPerfil.isNotEmpty
                    ? NetworkImage(user.fotoPerfil)
                    : null,
                child: user.fotoPerfil.isEmpty
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
              const SizedBox(height: 16),
              // Nombre y edad
              Text(
                '${user.nombre}, ${user.edad}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              // Ubicación
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    user.origen,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Tarjeta de piso
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.apartment_rounded,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¡Tiene piso!',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${user.precioAlquilerPorPersona}€/mes por persona',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Botón Ver perfil
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileDetailScreen(userUid: user.uid),
                      ),
                    );
                  },
                  child: const Text('Ver perfil completo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: (controller) {
          _mapController = controller;
        },
        initialCameraPosition: const CameraPosition(
          target: _initialPosition,
          zoom: 12,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
