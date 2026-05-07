import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/user_profile.dart';

class DemoChatScreen extends StatefulWidget {
  const DemoChatScreen({super.key, required this.otherUser});

  final UserProfile otherUser;

  @override
  State<DemoChatScreen> createState() => _DemoChatScreenState();
}

class _DemoChatScreenState extends State<DemoChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Seed a couple of demo messages
    _messages.addAll([
      {
        'from': widget.otherUser.uid,
        'text': 'Hola, gracias por conectar. ¿Qué zona te interesa?',
        'time': DateTime.now().subtract(const Duration(minutes: 55)),
      },
      {
        'from': 'demo_me',
        'text': 'Gracias! Busco algo en el centro de Madrid.',
        'time': DateTime.now().subtract(const Duration(minutes: 50)),
      },
    ]);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(
      () => _messages.add({
        'from': 'demo_me',
        'text': text,
        'time': DateTime.now(),
      }),
    );
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 400), () {
      setState(
        () => _messages.add({
          'from': widget.otherUser.uid,
          'text': 'Perfecto, te comparto fotos en un momento.',
          'time': DateTime.now(),
        }),
      );
    });
    if (widget.otherUser.fotosPiso.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) {
          return;
        }
        setState(
          () => _messages.add({
            'from': widget.otherUser.uid,
            'text': 'Te dejo algunas fotos del piso.',
            'photos': widget.otherUser.fotosPiso.take(2).toList(),
            'time': DateTime.now(),
          }),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: AssetImage(widget.otherUser.fotoPerfil),
            ),
            const SizedBox(width: 12),
            Text(widget.otherUser.nombre),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final fromMe = msg['from'] == 'demo_me';
                final photos = List<String>.from(
                  (msg['photos'] as List?) ?? const <String>[],
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  alignment: fromMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: fromMe ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECECEC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['text'] as String,
                          style: TextStyle(
                            color: fromMe ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        if (photos.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 120,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: photos.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, photoIndex) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.asset(
                                    photos[photoIndex],
                                    width: 150,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje de presentación...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _send,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
