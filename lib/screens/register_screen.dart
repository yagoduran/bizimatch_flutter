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
  final _estudiosCtrl = TextEditingController();
  final _origenCtrl = TextEditingController();
  final _lugarDeseadoCtrl = TextEditingController();
  final _precioAlquilerCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _repeatPasswordCtrl = TextEditingController();

  DateTime? _fechaNacimiento;
  String _genero = 'Mujer';
  String _horario = 'Mañana';
  bool _fumador = false;
  bool _mascotas = false;
  bool _tienePiso = false;
  bool _loading = false;
  XFile? _pickedFile;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _estudiosCtrl.dispose();
    _origenCtrl.dispose();
    _lugarDeseadoCtrl.dispose();
    _precioAlquilerCtrl.dispose();
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
        estudios: _estudiosCtrl.text.trim(),
        fumador: _fumador,
        mascotas: _mascotas,
        tienePiso: _tienePiso,
        precioAlquilerPorPersona: _tienePiso
            ? int.tryParse(_precioAlquilerCtrl.text.trim().replaceAll(',', '.'))
            : null,
        horario: _horario,
        bio: 'Buscando compañeros de piso compatibles para convivir bien.',
        fotoPerfil: _pickedFile?.path ?? '',
        intereses: const <String>[],
        email: _emailCtrl.text.trim(),
        lugarDeseado: _lugarDeseadoCtrl.text.trim(),
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
      _showError('Error de autenticación: ${e.code}');
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
      appBar: AppBar(title: const Text('Crear cuenta')),
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
                initialValue: _genero,
                decoration: const InputDecoration(labelText: 'Género'),
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
              TextFormField(
                controller: _estudiosCtrl,
                decoration: const InputDecoration(labelText: '¿Qué estudias?'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lugarDeseadoCtrl,
                decoration: const InputDecoration(
                  labelText: '¿Dónde deseas vivir? (Ciudad/Zona)',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Opcional' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _horario,
                decoration: const InputDecoration(
                  labelText: 'Horario principal',
                ),
                items: const [
                  DropdownMenuItem(value: 'Mañana', child: Text('Mañana')),
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
                activeThumbColor: AppTheme.primary,
                title: const Text('¿Fumador?'),
                onChanged: (value) => setState(() => _fumador = value),
              ),
              SwitchListTile(
                value: _mascotas,
                activeThumbColor: AppTheme.primary,
                title: const Text('¿Mascotas?'),
                onChanged: (value) => setState(() => _mascotas = value),
              ),
              SwitchListTile(
                value: _tienePiso,
                activeThumbColor: AppTheme.primary,
                title: const Text('¿Tienes piso ya?'),
                onChanged: (value) => setState(() {
                  _tienePiso = value;
                  if (!value) {
                    _precioAlquilerCtrl.clear();
                  }
                }),
              ),
              if (_tienePiso) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _precioAlquilerCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio alquiler por persona (EUR/mes)',
                  ),
                  validator: (value) {
                    if (!_tienePiso) {
                      return null;
                    }
                    final raw = (value ?? '').trim().replaceAll(',', '.');
                    final parsed = double.tryParse(raw);
                    if (parsed == null || parsed <= 0) {
                      return 'Introduce un precio valido mayor a 0';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    v == null || !v.contains('@') ? 'Email inválido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                validator: (v) =>
                    v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repeatPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Repetir contraseña',
                ),
                validator: (v) => v != _passwordCtrl.text
                    ? 'Las contraseñas no coinciden'
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
                    : const Text('Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
