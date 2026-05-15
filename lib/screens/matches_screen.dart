import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../widgets/app_cached_network_image.dart';
import '../widgets/glassmorphism.dart';
import 'chat_detail_screen.dart';
import '../services/demo_service.dart';
import 'demo_chat_screen.dart';
import 'profile_detail_screen.dart';

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
  int _demoRevision = 0;

  @override
  void initState() {
    super.initState();
    _threadsStream = _firestore.chatThreads();
    DemoService.instance.resetRevision.addListener(_onDemoReset);
  }

  void _onDemoReset() {
    if (!mounted) {
      return;
    }
    setState(() => _demoRevision = DemoService.instance.resetRevision.value);
  }

  @override
  void dispose() {
    DemoService.instance.resetRevision.removeListener(_onDemoReset);
    super.dispose();
  }

  Future<UserProfile?> _userFuture(String uid) {
    if (DemoService.instance.isDemoMode.value && uid.startsWith('demo')) {
      final demo = DemoService.instance.demoProfiles.firstWhere(
        (p) => p.uid == uid,
        orElse: () => DemoService.instance.demoProfiles.first,
      );
      return Future.value(demo);
    }
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
    if (DemoService.instance.isDemoMode.value && otherUid.startsWith('demo')) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DemoChatScreen(
            otherUser: DemoService.instance.demoProfiles.firstWhere(
              (p) => p.uid == otherUid,
            ),
          ),
        ),
      );
      return;
    }
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

  Future<void> _openProfileDetail(BuildContext context, String otherUid) async {
    if (otherUid.trim().isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailScreen(
          userUid: otherUid,
          heroTag: 'profile_image_$otherUid',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final threadsStream = DemoService.instance.isDemoMode.value
        ? Stream<List<ChatThread>>.value(DemoService.instance.demoThreads)
        : _threadsStream;
    final myUid = DemoService.instance.isDemoMode.value
        ? 'demo_me'
        : FirebaseAuth.instance.currentUser?.uid ?? '';

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
                key: ValueKey<int>(_demoRevision),
                stream: threadsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const ShimmerSkeleton(itemCount: 5);
                  }

                  final threads = snapshot.data ?? const <ChatThread>[];
                  if (threads.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.forum_outlined,
                      title: 'No tienes conversaciones activas',
                      message:
                          'Cuando hagas match o te apuntes a un plan, verás aquí los vínculos disponibles.',
                      actionLabel: 'Explorar perfiles',
                      onAction: () {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ve a Descubrir para empezar a crear vínculos.'),
                          ),
                        );
                      },
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

                          return FadeInUp(
                            key: ValueKey<String>(thread.chatId),
                            duration: itemDuration,
                            delay: Duration(milliseconds: index * 35),
                            from: 14,
                            child: GlassCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.zero,
                              borderRadius: 28,
                              glowColor: index.isEven
                                  ? AppTheme.primary
                                  : AppTheme.indigo,
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
                                leading: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      _openProfileDetail(context, otherUid),
                                  child: Hero(
                                    tag: 'profile_image_$otherUid',
                                    child: AppCachedAvatar(
                                      imageUrl: avatarUrl,
                                      radius: 26,
                                      backgroundColor:
                                          const Color(0xFFE7F4EE),
                                    ),
                                  ),
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
