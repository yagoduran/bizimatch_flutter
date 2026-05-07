import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/community_plan_model.dart';
import '../services/community_service.dart';
import '../services/demo_service.dart';

class CommunityPlanChatScreen extends StatefulWidget {
  const CommunityPlanChatScreen({super.key, required this.plan});

  final CommunityPlan plan;

  @override
  State<CommunityPlanChatScreen> createState() =>
      _CommunityPlanChatScreenState();
}

class _CommunityPlanChatScreenState extends State<CommunityPlanChatScreen> {
  final CommunityService _communityService = CommunityService.instance;
  final TextEditingController _controller = TextEditingController();
  final List<CommunityPlanMessage> _demoMessages = <CommunityPlanMessage>[];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (DemoService.instance.isDemoMode.value) {
      _demoMessages.addAll([
        CommunityPlanMessage(
          id: 'demo_msg_1',
          planId: widget.plan.id,
          senderId: 'demo_1',
          senderName: 'Daniel Ruiz',
          texto: 'Yo puedo llegar 10 min antes y reservar mesa.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
        ),
        CommunityPlanMessage(
          id: 'demo_msg_2',
          planId: widget.plan.id,
          senderId: 'demo_2',
          senderName: 'Lucia Fernandez',
          texto: 'Perfecto, llevo una lista de preguntas para pisos.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 22)),
        ),
      ]);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final user = FirebaseAuth.instance.currentUser;
    final senderName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'Usuario';

    setState(() => _sending = true);
    _controller.clear();
    HapticFeedback.lightImpact();

    if (DemoService.instance.isDemoMode.value) {
      setState(() {
        _demoMessages.add(
          CommunityPlanMessage(
            id: 'demo_msg_${DateTime.now().millisecondsSinceEpoch}',
            planId: widget.plan.id,
            senderId: myUidForDemo,
            senderName: 'Admin Demo',
            texto: text,
            createdAt: DateTime.now(),
          ),
        );
        _sending = false;
      });
      return;
    }

    try {
      await _communityService.enviarMensajePlan(
        planId: widget.plan.id,
        texto: text,
        senderName: senderName,
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = DemoService.instance.isDemoMode.value
        ? myUidForDemo
        : FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text('Chat: ${widget.plan.titulo}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CommunityPlanMessage>>(
              stream: DemoService.instance.isDemoMode.value
                  ? Stream<List<CommunityPlanMessage>>.value(_demoMessages)
                  : _communityService.mensajesPlan(widget.plan.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages =
                    snapshot.data ?? const <CommunityPlanMessage>[];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Aun no hay mensajes. Rompe el hielo ✨'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final mine = msg.senderId == myUid;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF7F3FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!mine)
                              Text(
                                msg.senderName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6D4FAF),
                                ),
                              ),
                            Text(
                              msg.texto,
                              style: TextStyle(
                                color: mine ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Escribe para coordinar...',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
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

const String myUidForDemo = 'demo_me';
