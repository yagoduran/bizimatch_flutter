import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/escuadron_model.dart';
import '../models/housing_model.dart';
import '../services/escuadron_service.dart';
import '../services/housing_service.dart';
import '../widgets/app_cached_network_image.dart';

class SquadHousingBrowserScreen extends StatefulWidget {
  final String squadId;

  const SquadHousingBrowserScreen({super.key, required this.squadId});

  @override
  State<SquadHousingBrowserScreen> createState() =>
      _SquadHousingBrowserScreenState();
}

class _SquadHousingBrowserScreenState extends State<SquadHousingBrowserScreen> {
  final EscuadronService _escuadronService = EscuadronService.instance;
  final HousingService _housingService = HousingService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late Stream<Escuadron?> _squadStream;
  late String _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser?.uid ?? '';
    _squadStream = _escuadronService.getEscuadronStream(widget.squadId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2FBF7),
      appBar: AppBar(
        title: Text(
          '🏠 Buscar Viviendas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF10B981),
        elevation: 0,
      ),
      body: StreamBuilder<Escuadron?>(
        stream: _squadStream,
        builder: (context, squadSnapshot) {
          if (squadSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!squadSnapshot.hasData || squadSnapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text('Escuadron no encontrado'),
                ],
              ),
            );
          }

          final squad = squadSnapshot.data!;

          return StreamBuilder<List<Housing>>(
            stream: _housingService.getHousingStreamForSquad(squad),
            builder: (context, housingSnapshot) {
              if (housingSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final housings = housingSnapshot.data ?? [];

              if (housings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home_work_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text('No hay viviendas disponibles'),
                      SizedBox(height: 8),
                      Text(
                        'para ${squad.miembrosCount} personas en ${squad.preferenciasComunas.zona ?? 'tu zona'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: housings.length,
                itemBuilder: (context, index) {
                  final housing = housings[index];
                  return _buildHousingCard(housing, squad, context);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHousingCard(
    Housing housing,
    Escuadron squad,
    BuildContext context,
  ) {
    final myLike = housing.usuarioLaDio(_myUid);
    final allLiked = squad.listaMiembrosIds.every(
      (uid) => housing.usuarioLaDio(uid),
    );

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allLiked ? Color(0xFF10B981) : Color(0xFFD4EEE1),
          width: allLiked ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          if (housing.fotos.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              child: AppCachedNetworkImage(
                imageUrl: housing.fotos[0],
                height: 180,
                fit: BoxFit.cover,
              ),
            ),

          // Info
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titulo y badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        housing.titulo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (allLiked)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Listo!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),

                // Ubicacion
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        housing.zona,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Especificaciones
                Row(
                  children: [
                    _specBadge(
                      icon: Icons.door_front_door,
                      label: '${housing.numHabitaciones} hab.',
                    ),
                    SizedBox(width: 8),
                    _specBadge(
                      icon: Icons.bathtub,
                      label: '${housing.numBanyos} baños',
                    ),
                    SizedBox(width: 8),
                    _specBadge(
                      icon: Icons.square_foot,
                      label: '${housing.metrosCuadrados.toInt()} m²',
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Precio
                Text(
                  '${housing.precioMensual.toStringAsFixed(0)}€/mes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
                SizedBox(height: 12),

                // Squad progress
                _buildSquadProgress(squad, housing),
                SizedBox(height: 12),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Ver más detalles
                        },
                        icon: Icon(Icons.info_outline),
                        label: Text('Detalles'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          if (myLike) {
                            await _housingService.unlikeHousing(
                              housing.id,
                              _myUid,
                            );
                          } else {
                            await _housingService.likeHousing(
                              housing.id,
                              _myUid,
                            );
                          }
                          setState(() {});
                        },
                        icon: Icon(
                          myLike ? Icons.favorite : Icons.favorite_border,
                        ),
                        label: Text(myLike ? 'Me gusta' : 'Marcar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myLike
                              ? Color(0xFF10B981)
                              : Colors.grey[300],
                          foregroundColor: myLike
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specBadge({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFFF2FBF7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Color(0xFFD4EEE1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Color(0xFF10B981)),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadProgress(Escuadron squad, Housing housing) {
    final memberLikes = squad.listaMiembrosIds
        .where((uid) => housing.usuarioLaDio(uid))
        .length;

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Color(0xFFF2FBF7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.people, size: 16, color: Color(0xFF10B981)),
          SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: memberLikes / squad.miembrosCount,
              backgroundColor: Color(0xFFD4EEE1),
              valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
              minHeight: 6,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '$memberLikes/${squad.miembrosCount}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }
}
