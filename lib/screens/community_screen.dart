import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/community_plan_model.dart';
import '../services/community_service.dart';
import 'community_plan_chat_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CommunityService _communityService = CommunityService.instance;
  String? _selectedCity;

  static const List<Color> _postItPalette = <Color>[
    Color(0xFFFFF2CC),
    Color(0xFFFFE3EC),
    Color(0xFFE8F9FF),
    Color(0xFFEFFFE8),
    Color(0xFFF4ECFF),
  ];

  @override
  void initState() {
    super.initState();
    _initCity();
  }

  Future<void> _initCity() async {
    final city = await _communityService.obtenerCiudadUsuario();
    if (!mounted) return;
    setState(() => _selectedCity = city);
  }

  @override
  Widget build(BuildContext context) {
    final city = _selectedCity;
    if (city == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      appBar: AppBar(
        title: const Text('Modo Comunidad'),
        actions: [
          StreamBuilder<List<String>>(
            stream: _communityService.ciudadesDisponibles(),
            builder: (context, snapshot) {
              final cities = snapshot.data ?? <String>[city];
              if (!cities.contains(city)) {
                cities.add(city);
              }
              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: city,
                  icon: const Icon(Icons.location_city, color: Colors.white),
                  dropdownColor: const Color(0xFF0F9D74),
                  style: const TextStyle(color: Colors.white),
                  items: cities
                      .map(
                        (c) =>
                            DropdownMenuItem<String>(value: c, child: Text(c)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedCity = value);
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<CommunityPlan>>(
        stream: _communityService.planesPorCiudad(city),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final plans = snapshot.data ?? const <CommunityPlan>[];
          if (plans.isEmpty) {
            return const Center(
              child: Text('No hay planes aun. ¡Crea el primero!'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final bg = _postItPalette[index % _postItPalette.length];
              return _buildPlanCard(plan, bg);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        onPressed: () => _showCreatePlanDialog(city),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Crear Plan'),
      ),
    );
  }

  Widget _buildPlanCard(CommunityPlan plan, Color bgColor) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final joined = plan.isAttending(myUid);
    final now = DateTime.now();
    final day = plan.fechaHora.day.toString().padLeft(2, '0');
    final month = plan.fechaHora.month.toString().padLeft(2, '0');
    final hh = plan.fechaHora.hour.toString().padLeft(2, '0');
    final mm = plan.fechaHora.minute.toString().padLeft(2, '0');
    final past = plan.fechaHora.isBefore(now);

    IconData icon = Icons.celebration;
    if (plan.tipoPlan == 'canas') icon = Icons.local_bar;
    if (plan.tipoPlan == 'deporte') icon = Icons.directions_run;
    if (plan.tipoPlan == 'turismo') icon = Icons.map;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0F9D74)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.titulo,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(plan.descripcion, style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 8),
          Text('🕒 $day/$month $hh:$mm  •  ${plan.ciudad}'),
          const SizedBox(height: 3),
          Text('Organiza: ${plan.creadorNombre}'),
          const SizedBox(height: 3),
          Text('Asistentes: ${plan.asistentesCount}'),
          if (past)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Este plan ya ha pasado',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await _communityService.toggleAsistencia(plan);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: joined
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(joined ? Icons.check_circle : Icons.group_add),
                  label: Text(joined ? 'Ya estoy dentro' : 'Me apunto'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: joined
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunityPlanChatScreen(plan: plan),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCreatePlanDialog(String city) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final placeController = TextEditingController(text: city);
    var tipo = 'canas';
    var selectedDate = DateTime.now().add(const Duration(hours: 2));

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nuevo Plan Comunitario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Titulo'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripcion',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: placeController,
                      decoration: const InputDecoration(labelText: 'Ciudad'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: tipo,
                      items: const [
                        DropdownMenuItem(
                          value: 'canas',
                          child: Text('Cañas 🍻'),
                        ),
                        DropdownMenuItem(
                          value: 'deporte',
                          child: Text('Deporte 🏃'),
                        ),
                        DropdownMenuItem(
                          value: 'turismo',
                          child: Text('Turismo 🗺️'),
                        ),
                        DropdownMenuItem(value: 'otro', child: Text('Otro ✨')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setStateDialog(() => tipo = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tipo de plan',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(
                        'Fecha/hora: ${selectedDate.day}/${selectedDate.month} ${selectedDate.hour.toString().padLeft(2, '0')}:${selectedDate.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date == null) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        if (time == null) return;
                        setStateDialog(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Publicar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final uid = FirebaseAuth.instance.currentUser;
    final creatorName = uid?.displayName?.trim().isNotEmpty == true
        ? uid!.displayName!.trim()
        : 'Usuario';

    try {
      await _communityService.crearPlan(
        titulo: titleController.text.trim(),
        descripcion: descController.text.trim(),
        ciudad: placeController.text.trim().isEmpty
            ? city
            : placeController.text.trim(),
        fechaHora: selectedDate,
        tipoPlan: tipo,
        creadorNombre: creatorName,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan publicado en Comunidad ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo crear el plan: $e')));
    }
  }
}
