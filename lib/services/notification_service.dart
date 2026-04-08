import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
        'chat_messages_channel',
        'Mensajes de chat',
        description: 'Notificaciones para mensajes entrantes del chat.',
        importance: Importance.high,
      );

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(_chatChannel);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    _messaging.onTokenRefresh.listen((token) {
      _saveTokenForCurrentUser(token);
    });

    _initialized = true;
  }

  Future<void> requestNotificationPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<String?> getFcmToken() {
    return _messaging.getToken();
  }

  Future<void> syncTokenForCurrentUser() async {
    final token = await getFcmToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }
    await _saveTokenForCurrentUser(token);
  }

  Future<void> _saveTokenForCurrentUser(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || token.trim().isEmpty) {
      return;
    }

    await _firestore.collection('usuarios').doc(uid).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Nuevo mensaje';
    final body =
        message.notification?.body ??
        (message.data['body'] as String?) ??
        'Tienes una nueva notificación';

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannel.id,
          _chatChannel.name,
          channelDescription: _chatChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // Estructura preparada para disparar notificaciones al receptor.
  // El envío real debe hacerlo backend/Cloud Functions por seguridad.
  Future<void> prepareChatNotification({
    required String receiverUid,
    required String senderUid,
    required String senderName,
    required String chatId,
    required String messageText,
  }) async {
    if (receiverUid.trim().isEmpty || messageText.trim().isEmpty) {
      return;
    }

    final receiverDoc = await _firestore
        .collection('usuarios')
        .doc(receiverUid)
        .get();
    final receiverToken = (receiverDoc.data()?['fcmToken'] ?? '') as String;

    await _firestore.collection('notificaciones_pendientes').add({
      'type': 'chat_message',
      'receiverUid': receiverUid,
      'receiverToken': receiverToken,
      'senderUid': senderUid,
      'senderName': senderName,
      'chatId': chatId,
      'messageText': messageText,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}
