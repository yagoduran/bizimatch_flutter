import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../screens/coexistence_pact_screen.dart';
import '../screens/expense_calculator_screen.dart';
import '../services/bizibot_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_cached_network_image.dart';
import '../widgets/glassmorphism.dart';

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
  final BiziBotService _biziBotService = BiziBotService.instance;
  final TextEditingController _controller = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  bool _isSending = false;
  bool _biziBotLoading = false;

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

  Future<void> _openBiziBotSuggestions() async {
    HapticFeedback.lightImpact();
    setState(() => _biziBotLoading = true);

    try {
      final suggestions = await _biziBotService.generarSugerencias(
        widget.otherUid,
      );
      if (!mounted) return;

      setState(() => _biziBotLoading = false);

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: AnimatedRainbowBorder(
              borderRadius: 32,
              child: GlassCard(
                borderRadius: 30,
                glowColor: AppTheme.indigo,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9F7AEA), Color(0xFF10B981)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Sugerencias de BiziBot',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(suggestions.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            _controller.text = suggestions[index];
                            Navigator.pop(context);
                            HapticFeedback.mediumImpact();
                          },
                          child: SizedBox(
                            width: double.infinity,
                            child: GlassCard(
                              padding: const EdgeInsets.all(14),
                              borderRadius: 24,
                              glowColor: index.isEven
                                  ? AppTheme.primary
                                  : AppTheme.violet,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    suggestions[index],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Toca para enviar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFA1A1A1),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    Center(
                      child: Text(
                        'Sugerencias generadas por BiziBot AI',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _biziBotLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                    return EmptyStateWidget(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Aún no hay mensajes',
                      message:
                          'Empieza la conversación sobre el piso con un mensaje claro y cercano.',
                      actionLabel: 'Escribir ahora',
                      onAction: _openExpenseCalculator,
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
                          child: GlassCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            borderRadius: 24,
                            glowColor: isMine
                                ? AppTheme.primary
                                : AppTheme.indigo,
                            gradient: isMine
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF10B981), Color(0xFF0F9D74)],
                                  )
                                : AppTheme.glassGradient,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 290),
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
                      scale: _biziBotLoading ? 0.94 : 1,
                      duration: AppTheme.motionChatMessage,
                      curve: AppTheme.motionCurve,
                      child: _biziBotLoading
                          ? GlassCard(
                              borderRadius: 16,
                              padding: const EdgeInsets.all(0),
                              glowColor: AppTheme.violet,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF9F7AEA), Color(0xFF10B981)],
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : GlowIconButton(
                              icon: Icons.auto_awesome,
                              onPressed: _openBiziBotSuggestions,
                              size: 48,
                              colors: const [Color(0xFF9F7AEA), Color(0xFF10B981)],
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
