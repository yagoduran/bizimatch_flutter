import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import 'chat_detail_screen.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Companeros',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<ChatThread>>(
                stream: firestore.chatThreads(),
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
                        (id) => id != myUid,
                        orElse: () => '',
                      );

                      return FutureBuilder<UserProfile?>(
                        future: firestore.getUserById(otherUid),
                        builder: (context, userSnapshot) {
                          final user = userSnapshot.data;
                          final name = user?.nombre ?? 'Usuario';
                          final avatarUrl = user?.fotoPerfil ?? '';
                          final hora = thread.updatedAt == null
                              ? ''
                              : '${thread.updatedAt!.hour.toString().padLeft(2, '0')}:${thread.updatedAt!.minute.toString().padLeft(2, '0')}';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => ChatDetailScreen(
                                      chatId: thread.chatId,
                                      otherUid: otherUid,
                                      otherName: name,
                                      avatarUrl: avatarUrl,
                                    ),
                                  ),
                                );
                              },
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
