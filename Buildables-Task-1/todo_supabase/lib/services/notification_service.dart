import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static NotificationService? _instance;
  factory NotificationService() =>
      _instance ??= NotificationService._internal();
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  FlutterLocalNotificationsPlugin? _localNotifications;
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _fcmToken;

  // Getters
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    if (kDebugMode) {
      print('🔔 [NOTIFICATION] Initializing Firebase and notifications...');
    }

    try {
      // Only initialize Firebase on mobile platforms (not web)
      if (!kIsWeb) {
        // Initialize Firebase
        await Firebase.initializeApp();

        // Initialize Firebase Messaging after Firebase is ready
        _firebaseMessaging = FirebaseMessaging.instance;

        if (kDebugMode) {
          print('✅ [NOTIFICATION] Firebase initialized successfully');
        }

        // Request permissions
        await _requestPermissions();

        // Get FCM token
        await _getFCMToken();

        // Setup message handlers
        await _setupMessageHandlers();
      } else {
        if (kDebugMode) {
          print(
            'ℹ️ [NOTIFICATION] Running on web - skipping Firebase initialization',
          );
        }
      }

      // Initialize local notifications (works on all platforms)
      await _initializeLocalNotifications();

      if (kDebugMode) {
        print('✅ [NOTIFICATION] Notification service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [NOTIFICATION] Failed to initialize notification service: $e');
      }
    }
  }

  Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications!.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'default_channel',
      'Default Notifications',
      description: 'Default notification channel for Todo Supabase',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications!
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    if (kDebugMode) {
      print('✅ [NOTIFICATION] Local notifications initialized');
    }
  }

  Future<void> _requestPermissions() async {
    if (_firebaseMessaging == null) return;

    NotificationSettings settings = await _firebaseMessaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print(
        '🔔 [NOTIFICATION] Permission status: ${settings.authorizationStatus}',
      );
    }
  }

  Future<void> _getFCMToken() async {
    if (_firebaseMessaging == null) return;

    try {
      _fcmToken = await _firebaseMessaging!.getToken();

      if (_fcmToken != null) {
        if (kDebugMode) {
          print(
            '🔔 [NOTIFICATION] FCM Token obtained: ${_fcmToken!.substring(0, 20)}...',
          );
        }

        // Store token in Supabase
        await _storeDeviceToken();
      } else {
        if (kDebugMode) {
          print('❌ [NOTIFICATION] Failed to get FCM token');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [NOTIFICATION] Error getting FCM token: $e');
      }
    }
  }

  Future<void> _storeDeviceToken() async {
    if (_fcmToken == null) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) {
          print(
            '⚠️ [NOTIFICATION] No authenticated user, skipping token storage',
          );
        }
        return;
      }

      // Store or update device token
      await _supabase.from('user_device_tokens').upsert({
        'user_id': userId,
        'device_token': _fcmToken,
        'device_type': _getDeviceType(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        print('✅ [NOTIFICATION] Device token stored in database');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [NOTIFICATION] Failed to store device token: $e');
      }
    }
  }

  String _getDeviceType() {
    // This is a simple implementation - you might want to use device_info_plus for more accurate detection
    return 'mobile'; // Could be 'android', 'ios', 'web'
  }

  Future<void> _setupMessageHandlers() async {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handle messages when app is terminated
    FirebaseMessaging.instance.getInitialMessage().then(
      _handleTerminatedMessage,
    );

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(_handleTokenRefresh);

    if (kDebugMode) {
      print('✅ [NOTIFICATION] Message handlers setup complete');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print(
        '🔔 [NOTIFICATION] Received foreground message: ${message.notification?.title}',
      );
    }

    // Show local notification
    _showLocalNotification(message);
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print(
        '🔔 [NOTIFICATION] App opened from background message: ${message.notification?.title}',
      );
    }

    // Handle navigation or other actions
    _handleNotificationAction(message);
  }

  void _handleTerminatedMessage(RemoteMessage? message) {
    if (message != null) {
      if (kDebugMode) {
        print(
          '🔔 [NOTIFICATION] App opened from terminated state: ${message.notification?.title}',
        );
      }

      // Handle navigation or other actions
      _handleNotificationAction(message);
    }
  }

  void _handleTokenRefresh(String token) {
    if (kDebugMode) {
      print('🔔 [NOTIFICATION] Token refreshed: ${token.substring(0, 20)}...');
    }

    _fcmToken = token;
    _storeDeviceToken();
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (_localNotifications == null) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'default_channel',
          'Default Notifications',
          channelDescription: 'Default notification channel for Todo Supabase',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications!.show(
      message.hashCode,
      message.notification?.title ?? 'Todo Supabase',
      message.notification?.body ?? 'You have a new notification',
      details,
      payload: message.data.toString(),
    );
  }

  void _handleNotificationAction(RemoteMessage message) {
    // Handle different types of notifications
    final data = message.data;

    if (data.containsKey('task_id')) {
      // Navigate to task detail
      final taskId = data['task_id'];
      if (kDebugMode) {
        print('🔔 [NOTIFICATION] Navigating to task: $taskId');
      }
      // You would implement navigation logic here
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('🔔 [NOTIFICATION] Notification tapped: ${response.payload}');
    }

    // Handle notification tap
    // You would implement navigation logic here
  }

  // Public methods for testing
  Future<void> testNotification() async {
    if (_localNotifications == null) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'default_channel',
          'Default Notifications',
          channelDescription: 'Default notification channel for Todo Supabase',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications!.show(
      0,
      'Test Notification',
      'This is a test notification from Todo Supabase!',
      details,
    );

    if (kDebugMode) {
      print('✅ [NOTIFICATION] Test notification sent');
    }
  }
}
