import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'main_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  final _nombreCtrl = TextEditingController();
  final _origenCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _repeatPasswordCtrl = TextEditingController();

  DateTime? _fechaNacimiento;
  String _genero = 'Mujer';
  String _horario = 'Manana';
  bool _fumador = false;
  bool _mascotas = false;
  bool _loading = false;
  XFile? _pickedFile;

  final List<String> _interesesDisponibles = const [
    'Limpieza',
    'Cocina',
    'Trabajo remoto',
    'Vida tranquila',
    'Deporte',
    'Estudio',
  ];
  final Set<String> _interesesSeleccionados = <String>{};

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _origenCtrl.dispose();
    _bioCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _repeatPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) {
      return;
    }
    setState(() {
      _pickedFile = image;
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 18),
      initialDate: DateTime(now.year - 25),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _fechaNacimiento = picked;
    });
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_fechaNacimiento == null) {
      _showError('Selecciona tu fecha de nacimiento.');
      return;
    }
    if (_interesesSeleccionados.isEmpty) {
      _showError('Selecciona al menos un interes.');
      return;
    }

    setState(() => _loading = true);
    try {
      final credential = await _authService.register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final profile = UserProfile(
        uid: credential.user!.uid,
        nombre: _nombreCtrl.text.trim(),
        fechaNacimiento: _fechaNacimiento!,
        genero: _genero,
        origen: _origenCtrl.text.trim(),
        fumador: _fumador,
        mascotas: _mascotas,
        horario: _horario,
        bio: _bioCtrl.text.trim(),
        fotoPerfil: _pickedFile?.path ?? '',
        intereses: _interesesSeleccionados.toList(growable: false),
      );

      await _firestoreService.saveUserProfile(profile);

      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const MainScaffold()),
      );
    } on FirebaseAuthException catch (e) {
      _showError('Error de autenticacion: ${e.code}');
    } catch (_) {
      _showError('No se pudo completar el registro.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta completa')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(54),
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: const Color(0xFFEAF5F1),
                    backgroundImage: _pickedFile != null
                        ? FileImage(File(_pickedFile!.path))
                        : null,
                    child: _pickedFile == null
                        ? const Icon(
                            Icons.add_a_photo_rounded,
                            size: 34,
                            color: AppTheme.primary,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de nacimiento',
                  ),
                  child: Text(
                    _fechaNacimiento == null
                        ? 'Seleccionar fecha'
                        : '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _genero,
                decoration: const InputDecoration(labelText: 'Genero'),
                items: const [
                  DropdownMenuItem(value: 'Mujer', child: Text('Mujer')),
                  DropdownMenuItem(value: 'Hombre', child: Text('Hombre')),
                  DropdownMenuItem(
                    value: 'No binario',
                    child: Text('No binario'),
                  ),
                  DropdownMenuItem(
                    value: 'Prefiero no decirlo',
                    child: Text('Prefiero no decirlo'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _genero = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _origenCtrl,
                decoration: const InputDecoration(labelText: 'Origen'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _horario,
                decoration: const InputDecoration(
                  labelText: 'Horario principal',
                ),
                items: const [
                  DropdownMenuItem(value: 'Manana', child: Text('Manana')),
                  DropdownMenuItem(value: 'Tarde', child: Text('Tarde')),
                  DropdownMenuItem(value: 'Noche', child: Text('Noche')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _horario = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _fumador,
                activeColor: AppTheme.primary,
                title: const Text('Soy fumador/a'),
                onChanged: (value) => setState(() => _fumador = value),
              ),
              SwitchListTile(
                value: _mascotas,
                activeColor: AppTheme.primary,
                title: const Text('Tengo mascotas'),
                onChanged: (value) => setState(() => _mascotas = value),
              ),
              const SizedBox(height: 8),
              const Text(
                'Intereses para afinidad',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _interesesDisponibles
                    .map((interes) {
                      final selected = _interesesSeleccionados.contains(
                        interes,
                      );
                      return FilterChip(
                        label: Text(interes),
                        selected: selected,
                        selectedColor: const Color(0xFFDDF5EC),
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _interesesSeleccionados.add(interes);
                            } else {
                              _interesesSeleccionados.remove(interes);
                            }
                          });
                        },
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Bio'),
                validator: (v) => v == null || v.trim().length < 12
                    ? 'Minimo 12 caracteres'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    v == null || !v.contains('@') ? 'Email invalido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contrasena'),
                validator: (v) =>
                    v == null || v.length < 6 ? 'Minimo 6 caracteres' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repeatPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Repetir contrasena',
                ),
                validator: (v) => v != _passwordCtrl.text
                    ? 'Las contrasenas no coinciden'
                    : null,
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear cuenta profesional'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
