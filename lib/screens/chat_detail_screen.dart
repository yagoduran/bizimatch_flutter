import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../screens/coexistence_pact_screen.dart';
import '../screens/expense_calculator_screen.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_cached_network_image.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherName,
    required this.avatarUrl,
  });

  final String chatId;
  final String otherUid;
  final String otherName;
  final String avatarUrl;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService.instance;
  final TextEditingController _controller = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messagesStream = _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('mensajes')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isSending = true);
    _controller.clear();

    try {
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('mensajes')
          .add({
            'texto': text,
            'text': text,
            'senderId': myUid,
            'emisorId': myUid,
            'timestamp': FieldValue.serverTimestamp(),
          });

      await _firestore.collection('chats').doc(widget.chatId).set({
        'participants': [myUid, widget.otherUid],
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final currentUser = FirebaseAuth.instance.currentUser;
      final senderName = currentUser?.displayName?.trim().isNotEmpty == true
          ? currentUser!.displayName!.trim()
          : (currentUser?.email ?? 'Nuevo mensaje');

      await _notificationService.prepareChatNotification(
        receiverUid: widget.otherUid,
        senderUid: myUid,
        senderName: senderName,
        chatId: widget.chatId,
        messageText: text,
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _openExpenseCalculator() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseCalculatorScreen(
          chatId: widget.chatId,
          onSendToChat: (message) {
            _controller.text = message;
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _openSafetyActions() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.block_rounded, color: Colors.red),
                  title: const Text('Bloquear usuario'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _firestoreService.bloquearUsuario(widget.otherUid);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Usuario bloqueado correctamente.'),
                      ),
                    );
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Reportar perfil'),
                  onTap: () async {
                    Navigator.pop(context);
                    final motivo = await _askReportReason();
                    if (motivo == null || motivo.isEmpty) {
                      return;
                    }
                    await _firestoreService.reportarUsuario(
                      reportadoUid: widget.otherUid,
                      motivo: motivo,
                      chatId: widget.chatId,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reporte enviado. Gracias por avisar.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _askReportReason() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reportar perfil'),
          content: const Text('Selecciona un motivo:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'Spam'),
              child: const Text('Spam'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'Fotos falsas'),
              child: const Text('Fotos falsas'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'Ofensivo'),
              child: const Text('Ofensivo'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        actions: [
          IconButton(
            onPressed: _openExpenseCalculator,
            icon: const Icon(Icons.calculate),
            tooltip: 'Calculadora de Gastos',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CoexistencePactScreen(
                    chatId: widget.chatId,
                    otherUid: widget.otherUid,
                    otherName: widget.otherName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.handshake),
            tooltip: 'Pacto de Convivencia',
          ),
          IconButton(
            onPressed: _openSafetyActions,
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Más opciones',
          ),
        ],
        title: Row(
          children: [
            AppCachedAvatar(
              imageUrl: widget.avatarUrl,
              radius: 20,
              backgroundColor: const Color(0xFFE7F4EE),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherName, style: textTheme.titleMedium),
                Text(
                  'Conversacion activa',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages =
                      snapshot.data?.docs ??
                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('Empieza la conversacion sobre el piso.'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final data = messages[index].data();
                      final senderId =
                          ((data['senderId'] ?? data['emisorId']) ?? '')
                              as String;
                      final text =
                          ((data['texto'] ?? data['text']) ?? '') as String;
                      final isMine = senderId == myUid;
                      return TweenAnimationBuilder<double>(
                        key: ValueKey<String>(messages[index].id),
                        duration: AppTheme.motionChatMessage,
                        curve: AppTheme.motionCurve,
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (context, value, child) {
                          final from = isMine ? 16.0 : -16.0;
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset((1 - value) * from, 0),
                              child: child,
                            ),
                          );
                        },
                        child: Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: const BoxConstraints(maxWidth: 290),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF1F3F4),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isMine
                                    ? const Color(0xFF0F9D74)
                                    : const Color(0xFFE2E8E4),
                              ),
                            ),
                            child: Text(
                              text,
                              style: TextStyle(
                                color: isMine
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: AnimatedScale(
                      scale: _isSending ? 0.94 : 1,
                      duration: AppTheme.motionChatMessage,
                      curve: AppTheme.motionCurve,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _send,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
