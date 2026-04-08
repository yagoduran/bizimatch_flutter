import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/escuadron_model.dart';
import '../models/user_model.dart';
import '../screens/squad_housing_browser_screen.dart';
import '../services/escuadron_service.dart';
import '../widgets/app_cached_network_image.dart';

class SquadScreen extends StatefulWidget {
  final String escuadronId;

  const SquadScreen({Key? key, required this.escuadronId}) : super(key: key);

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  final EscuadronService _escuadronService = EscuadronService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Color(0xFFF2FBF7),
      appBar: AppBar(
        title: Text(
          '👥 Escuadrón',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF10B981),
        elevation: 0,
      ),
      body: StreamBuilder<Escuadron?>(
        stream: _escuadronService.getEscuadronStream(widget.escuadronId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text('Escuadrón disuelto'),
                ],
              ),
            );
          }

          final escuadron = snapshot.data!;

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Miembros del escuadrón
                  Text(
                    'Miembros del Escuadrón',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildMembersList(escuadron, myUid),
                  SizedBox(height: 32),

                  // Preferencias comunes
                  _buildPreferencesCard(escuadron),
                  SizedBox(height: 24),

                  // Botón para buscar viviendas
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SquadHousingBrowserScreen(
                              squadId: widget.escuadronId,
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.home_search),
                      label: Text(
                        'Buscar Viviendas',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Botón disolver
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isOwnerOrLastMember(escuadron, myUid)
                          ? () => _showDissolveDialog(context, escuadron)
                          : null,
                      icon: Icon(Icons.exit_to_app),
                      label: Text(
                        _isOwnerOrLastMember(escuadron, myUid)
                            ? 'Disolver Escuadrón'
                            : 'Solo el líder puede disolver',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMembersList(Escuadron escuadron, String myUid) {
    return FutureBuilder<List<UserModel>>(
      future: _loadMembers(escuadron.listaMiembrosIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return Text('No hay miembros');
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: escuadron.miembrosCount == 2 ? 2 : 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final isMe = member.id == myUid;

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: isMe
                    ? Border.all(color: Color(0xFF10B981), width: 3)
                    : Border.all(color: Color(0xFFD4EEE1), width: 1.5),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AppCachedNetworkImage(
                      imageUrl: member.fotoPerfil,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (isMe)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      padding: EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            member.nombre.length > 12
                                ? member.nombre.substring(0, 12) + '...'
                                : member.nombre,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${member.edad} años',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreferencesCard(Escuadron escuadron) {
    final prefs = escuadron.preferenciasComunas;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF0F9D74)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 Preferencias Comunes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.euro, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Presupuesto Máximo',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      prefs.precioMaximo != null
                          ? '${prefs.precioMaximo!.toStringAsFixed(2)}€'
                          : 'Sin límite',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zona Preferida',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      prefs.zona ?? 'Cualquiera',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  bool _isOwnerOrLastMember(Escuadron escuadron, String myUid) {
    // First member is considered owner, or if only one member left
    return escuadron.listaMiembrosIds.isEmpty ||
        escuadron.listaMiembrosIds[0] == myUid ||
        escuadron.listaMiembrosIds.length == 1;
  }

  void _showDissolveDialog(BuildContext context, Escuadron escuadron) {
    final myUid = _auth.currentUser?.uid ?? '';
    final isOnlyMember = escuadron.listaMiembrosIds.length == 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isOnlyMember ? 'Abandonar Escuadrón' : 'Disolver Escuadrón',
        ),
        content: Text(
          isOnlyMember
              ? '¿Estás seguro de que quieres abandonar el escuadrón?'
              : '¿Estás seguro de que quieres disolver el escuadrón completamente? Esto afectará a todos los miembros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              if (isOnlyMember) {
                await _escuadronService.removerMiembro(
                  widget.escuadronId,
                  myUid,
                );
              } else {
                await _escuadronService.disolverEscuadron(widget.escuadronId);
              }

              HapticFeedback.mediumImpact();

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isOnlyMember
                        ? 'Has abandonado el escuadrón'
                        : 'Escuadrón disuelto',
                  ),
                  backgroundColor: Color(0xFF10B981),
                ),
              );

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
            child: Text(
              isOnlyMember ? 'Abandonar' : 'Disolver',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
