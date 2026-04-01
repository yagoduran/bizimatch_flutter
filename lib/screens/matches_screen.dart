import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import 'chat_detail_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final FirestoreService _firestore = FirestoreService();
  final Map<String, Future<UserProfile?>> _userCache =
      <String, Future<UserProfile?>>{};
  late final Stream<List<ChatThread>> _threadsStream;
  late final String _myUid;

  @override
  void initState() {
    super.initState();
    _threadsStream = _firestore.chatThreads();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Future<UserProfile?> _userFuture(String uid) {
    return _userCache.putIfAbsent(uid, () => _firestore.getUserById(uid));
  }

  Future<void> _openChat(
    BuildContext context,
    ChatThread thread,
    String otherUid,
    String name,
    String avatarUrl,
  ) async {
    HapticFeedback.selectionClick();
    await Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: AppTheme.motionNavigation,
        reverseTransitionDuration: AppTheme.motionFast,
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChatDetailScreen(
              chatId: thread.chatId,
              otherUid: otherUid,
              otherName: name,
              avatarUrl: avatarUrl,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offset =
              Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: AppTheme.motionCurve),
              );
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: offset, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text('Vínculos', style: textTheme.headlineMedium),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(
                  'Tus conversaciones activas y pendientes',
                  style: textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<ChatThread>>(
                stream: _threadsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final threads = snapshot.data ?? const <ChatThread>[];
                  if (threads.isEmpty) {
                    return const Center(
                      child: Text('Aun no tienes conversaciones activas.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: threads.length,
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      final otherUid = thread.participants.firstWhere(
                        (id) => id != _myUid,
                        orElse: () => '',
                      );

                      return FutureBuilder<UserProfile?>(
                        future: _userFuture(otherUid),
                        builder: (context, userSnapshot) {
                          final user = userSnapshot.data;
                          final name = user?.nombre ?? 'Usuario';
                          final avatarUrl = user?.fotoPerfil ?? '';
                          final hora = thread.updatedAt == null
                              ? ''
                              : '${thread.updatedAt!.hour.toString().padLeft(2, '0')}:${thread.updatedAt!.minute.toString().padLeft(2, '0')}';

                          final itemDuration = Duration(
                            milliseconds:
                                ((AppTheme.motionListItem.inMilliseconds +
                                            (index * 34))
                                        .clamp(
                                          AppTheme
                                              .motionListItem
                                              .inMilliseconds,
                                          520,
                                        ))
                                    .toInt(),
                          );

                          return TweenAnimationBuilder<double>(
                            key: ValueKey<String>(thread.chatId),
                            duration: itemDuration,
                            curve: AppTheme.motionCurve,
                            tween: Tween<double>(begin: 0, end: 1),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 10),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE8EFEB),
                                ),
                              ),
                              child: ListTile(
                                onTap: () => _openChat(
                                  context,
                                  thread,
                                  otherUid,
                                  name,
                                  avatarUrl,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: const Color(0xFFE7F4EE),
                                  backgroundImage: avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: avatarUrl.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          color: AppTheme.primary,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  thread.lastMessage.isEmpty
                                      ? 'Inicia una conversacion profesional.'
                                      : thread.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Text(
                                  hora,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
