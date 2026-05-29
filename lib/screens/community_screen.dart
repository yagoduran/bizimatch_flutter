import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/community_plan_model.dart';
import '../models/community_plan_type.dart';
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
  CommunityPlanType? _selectedTypeFilter;

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
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'No se pudieron cargar los planes.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Revisa tu conexi├│n o vuelve a intentarlo m├ís tarde.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final plans = _filteredPlans(
            snapshot.data ?? const <CommunityPlan>[],
          );

          if (plans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_available, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      _selectedTypeFilter == null
                          ? 'No hay planes aun en $city.'
                          : 'No hay planes de ${_selectedTypeFilter!.label.toLowerCase()} en $city.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Publica uno para romper el hielo con gente de la zona.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _showCreatePlanDialog(city),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Crear plan'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: plans.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildTypeFilters(),
                );
              }

              final plan = plans[index - 1];
              final bg = _postItPalette[(index - 1) % _postItPalette.length];
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

  List<CommunityPlan> _filteredPlans(List<CommunityPlan> plans) {
    final filtered = _selectedTypeFilter == null
        ? plans
        : plans
              .where((plan) => plan.tipoPlan == _selectedTypeFilter)
              .toList(growable: false);

    final sorted = filtered.toList()
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    return sorted;
  }

  Widget _buildTypeFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Todos'),
            selected: _selectedTypeFilter == null,
            onSelected: (_) {
              setState(() => _selectedTypeFilter = null);
            },
          ),
          const SizedBox(width: 8),
          ...CommunityPlanType.values.map((type) {
            final selected = _selectedTypeFilter == type;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                avatar: Icon(type.icon, size: 18),
                label: Text(type.label),
                onSelected: (_) {
                  setState(() {
                    _selectedTypeFilter = selected ? null : type;
                  });
                },
              ),
            );
          }),
        ],
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

    final icon = plan.tipoPlan.icon;

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag(plan.tipoPlan.label, plan.tipoPlan.icon),
              _buildTag(plan.ciudad, Icons.location_on_outlined),
              _buildTag(
                past ? 'Pasado' : 'Pr├│ximo',
                past ? Icons.history_toggle_off : Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(plan.descripcion, style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 8),
          Text('­ƒòÆ $day/$month $hh:$mm  ÔÇó  ${plan.ciudad}'),
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

  Widget _buildTag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0F9D74)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreatePlanDialog(String city) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final placeController = TextEditingController(text: city);
    var selectedType = CommunityPlanType.canas;
    var selectedDate = DateTime.now().add(const Duration(hours: 2));

    try {
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
                      DropdownButtonFormField<CommunityPlanType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de plan',
                        ),
                        items: CommunityPlanType.values
                            .map(
                              (type) => DropdownMenuItem<CommunityPlanType>(
                                value: type,
                                child: Text(
                                  '${type.label} ${type.icon == Icons.local_bar
                                      ? '­ƒì╗'
                                      : type.icon == Icons.directions_run
                                      ? '­ƒÅâ'
                                      : type.icon == Icons.map
                                      ? '­ƒù║´©Å'
                                      : 'Ô£¿'}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setStateDialog(() => selectedType = value);
                        },
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

      final user = FirebaseAuth.instance.currentUser;
      final creatorName = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : 'Usuario';

      await _communityService.crearPlan(
        titulo: titleController.text.trim(),
        descripcion: descController.text.trim(),
        ciudad: placeController.text.trim().isEmpty
            ? city
            : placeController.text.trim(),
        fechaHora: selectedDate,
        tipoPlan: selectedType,
        creadorNombre: creatorName,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan publicado en Comunidad Ô£à')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo crear el plan: $e')));
    } finally {
      titleController.dispose();
      descController.dispose();
      placeController.dispose();
    }
  }
}
