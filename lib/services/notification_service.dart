import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  /// NotificationService: lokalean eta FCM bidezko notifikazioen konfigurazioa kudeatzen du.
  ///
  /// Zer egiten duen:
  /// - Flutter Local Notifications konfiguratu eta FCM tokenak sinkronizatzen ditu.
  /// - Aurrealdeko mezuak eskuz erakutsi ditzake eta pendente notifikazioak gorde.
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
    if (_initialized) return;

    // Local notifications eta timezone konfigurazioa prestatu.
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    tz_data.initializeTimeZones();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(_chatChannel);

    // Aurrealdeko mezuak lokalki erakusteko entzulea.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // FCM token aldaketak sinkronizatu erabiltzailearekin.
    _messaging.onTokenRefresh.listen((token) {
      _saveTokenForCurrentUser(token);
    });

    _initialized = true;
  }

  Future<void> triggerDemoNotification() async {
    await initialize();
    await _localNotifications.zonedSchedule(
      1001,
      'BiziMatch',
      '¡Lucía ha completado: Limpiar Salón!',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
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
    // FCM token erabiltzailearen dokumentuan gordetzen da, sinkronizazio helburuarekin.
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

  // Nahi izanez gero, hemen prestatzen ditugu pendente notifikazioak bidaltzeko.
  // Ohar: segurtasunagatik bidalketa errealak backend edo Cloud Functions-ek egin behar dituzte.
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
