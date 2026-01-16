import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/firebase_options.dart';
import 'api_service.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class NotificationService extends ChangeNotifier {
  final ApiService _apiService;

  bool _isInitialized = false;
  bool _hasPermission = false;
  String? _fcmToken;
  NotificationSettings? _settings;

  // Local state for notification settings
  bool _enabled = false;
  int _priceChangeThreshold = 5;
  String? _quietHoursStart;
  String? _quietHoursEnd;

  NotificationService(this._apiService);

  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;
  String? get fcmToken => _fcmToken;
  bool get enabled => _enabled;
  int get priceChangeThreshold => _priceChangeThreshold;
  String? get quietHoursStart => _quietHoursStart;
  String? get quietHoursEnd => _quietHoursEnd;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Get messaging instance
      final messaging = FirebaseMessaging.instance;

      // Request permission
      _settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      _hasPermission = _settings?.authorizationStatus == AuthorizationStatus.authorized ||
          _settings?.authorizationStatus == AuthorizationStatus.provisional;

      if (kDebugMode) {
        print('Notification permission status: ${_settings?.authorizationStatus}');
      }

      if (_hasPermission) {
        // Get FCM token
        _fcmToken = await messaging.getToken();
        if (kDebugMode) {
          print('FCM Token: $_fcmToken');
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen(_handleTokenRefresh);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification tap when app was in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Check if app was opened from a notification
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notifications: $e');
      }
    }
  }

  void _handleTokenRefresh(String newToken) {
    if (kDebugMode) {
      print('FCM Token refreshed: $newToken');
    }

    final oldToken = _fcmToken;
    _fcmToken = newToken;

    // Re-register with backend
    if (oldToken != null && oldToken != newToken) {
      _unregisterToken(oldToken);
    }
    _registerToken(newToken);

    notifyListeners();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Foreground message received: ${message.notification?.title}');
    }
    // Could show an in-app notification here
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('Message opened app: ${message.data}');
    }
    // Handle navigation based on message data
    // e.g., navigate to specific asset screen
  }

  Future<void> registerTokenAfterLogin() async {
    if (_fcmToken == null || !_hasPermission) return;

    try {
      await _registerToken(_fcmToken!);
      await loadSettings();
    } catch (e) {
      if (kDebugMode) {
        print('Error registering token: $e');
      }
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await _apiService.post('/notifications/token', data: {'token': token});
      if (kDebugMode) {
        print('FCM token registered with backend');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error registering token with backend: $e');
      }
    }
  }

  Future<void> _unregisterToken(String token) async {
    try {
      await _apiService.delete('/notifications/token/$token');
      if (kDebugMode) {
        print('Old FCM token unregistered');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unregistering token: $e');
      }
    }
  }

  Future<void> unregisterTokenOnLogout() async {
    if (_fcmToken == null) return;

    try {
      await _unregisterToken(_fcmToken!);
    } catch (e) {
      if (kDebugMode) {
        print('Error unregistering token on logout: $e');
      }
    }
  }

  Future<void> loadSettings() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>('/notifications/settings');
      _enabled = response['enabled'] ?? false;
      _priceChangeThreshold = response['priceChangeThreshold'] ?? 5;
      _quietHoursStart = response['quietHoursStart'];
      _quietHoursEnd = response['quietHoursEnd'];
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading notification settings: $e');
      }
    }
  }

  Future<void> updateSettings({
    required bool enabled,
    required int priceChangeThreshold,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) async {
    try {
      await _apiService.put('/notifications/settings', data: {
        'enabled': enabled,
        'priceChangeThreshold': priceChangeThreshold,
        'quietHoursStart': quietHoursStart,
        'quietHoursEnd': quietHoursEnd,
      });

      _enabled = enabled;
      _priceChangeThreshold = priceChangeThreshold;
      _quietHoursStart = quietHoursStart;
      _quietHoursEnd = quietHoursEnd;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating notification settings: $e');
      }
      rethrow;
    }
  }

  Future<void> toggleEnabled(bool value) async {
    await updateSettings(
      enabled: value,
      priceChangeThreshold: _priceChangeThreshold,
      quietHoursStart: _quietHoursStart,
      quietHoursEnd: _quietHoursEnd,
    );
  }

  Future<void> setPriceChangeThreshold(int value) async {
    await updateSettings(
      enabled: _enabled,
      priceChangeThreshold: value,
      quietHoursStart: _quietHoursStart,
      quietHoursEnd: _quietHoursEnd,
    );
  }

  Future<void> setQuietHours(String? start, String? end) async {
    await updateSettings(
      enabled: _enabled,
      priceChangeThreshold: _priceChangeThreshold,
      quietHoursStart: start,
      quietHoursEnd: end,
    );
  }
}
