import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/firebase_options.dart';
import 'api_service.dart';
import '../../shared/widgets/in_app_notification.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background messages
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  debugPrint('[Notifications] Background message: ${message.messageId}');
  debugPrint('[Notifications] Background message data: ${message.data}');
  // Note: Widget refresh is handled by native AppDelegate calling WidgetCenter.reloadAllTimelines()
}

/// Service for managing push notifications via Firebase Cloud Messaging.
///
/// Handles:
/// - Firebase initialization
/// - Permission requests
/// - FCM token management
/// - Token registration with backend
/// - Notification settings
class NotificationService extends ChangeNotifier {
  final ApiService _apiService;

  // Initialization state
  bool _isInitialized = false;
  bool _hasPermission = false;
  bool _permissionRequested = false;
  String? _fcmToken;
  NotificationSettings? _notificationSettings;

  // User notification preferences (from backend)
  bool _enabled = false;
  int _priceChangeThreshold = 5;
  String? _quietHoursStart;
  String? _quietHoursEnd;
  List<String> _alertAssets = const [];

  // Configuration
  static const int _maxApnsRetries = 10;
  static const Duration _apnsRetryDelay = Duration(milliseconds: 500);

  NotificationService(this._apiService);

  // Getters
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;
  bool get permissionRequested => _permissionRequested;
  String? get fcmToken => _fcmToken;
  bool get enabled => _enabled;
  int get priceChangeThreshold => _priceChangeThreshold;
  String? get quietHoursStart => _quietHoursStart;
  String? get quietHoursEnd => _quietHoursEnd;

  /// Activos de los que llegan avisos. La API siempre devuelve la lista
  /// resuelta —si nunca elegiste, manda el conjunto por defecto—, así que acá
  /// no hay que distinguir "vacío" de "sin configurar".
  List<String> get alertAssets => List.unmodifiable(_alertAssets);

  bool followsAsset(String asset) =>
      _alertAssets.contains(asset.toUpperCase());

  /// Initialize the notification service.
  /// Should be called once at app startup.
  /// If [requestPermission] is false, permission won't be requested automatically.
  Future<void> initialize({bool requestPermission = false}) async {
    if (_isInitialized) return;

    try {
      await _initializeFirebase();
      if (requestPermission) {
        await _setupMessaging();
      } else {
        // Sin esto `_hasPermission` arrancaba en false y se quedaba ahí: la
        // pantalla mostraba "Sin permiso del sistema" en cada arranque aunque
        // el permiso estuviera concedido desde hacía meses.
        await refreshPermissionStatus();
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[Notifications] Initialization error: $e');
      debugPrint('[Notifications] Stack trace: $stackTrace');
      // Don't rethrow - app should work without notifications
    }
  }

  /// Request notification permissions and setup messaging.
  /// Call this after showing a custom permission UI to the user.
  /// Returns true if permission was granted, false otherwise.
  /// Consulta a iOS el estado real del permiso, sin pedirlo.
  ///
  /// Hay que rehacerlo cada vez que la pantalla se abre y cuando la app vuelve
  /// del fondo: el permiso se puede conceder o revocar desde Ajustes del
  /// sistema, fuera de la app, y el flag en memoria no se entera.
  Future<void> refreshPermissionStatus() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      _notificationSettings = settings;

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted != _hasPermission) {
        _hasPermission = granted;
        notifyListeners();
      }

      // El permiso ya estaba dado de antes: hay que enganchar los listeners y
      // el token igual, porque este arranque no pasó por _setupMessaging.
      if (granted && _fcmToken == null) {
        final messaging = FirebaseMessaging.instance;
        await _acquireFcmToken(messaging);
        _setupListeners(messaging);
      }
    } catch (e) {
      debugPrint('[Notifications] No se pudo leer el permiso: $e');
    }
  }

  Future<bool> requestPermissionAndSetup() async {
    if (_permissionRequested && _hasPermission) return true;

    try {
      await _setupMessaging();
      notifyListeners();
      return _hasPermission;
    } catch (e, stackTrace) {
      debugPrint('[Notifications] Permission request error: $e');
      debugPrint('[Notifications] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Initialize Firebase, handling the case where it's already initialized by native code.
  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (e) {
      // Firebase already initialized by iOS/Android native code
      if (!e.toString().contains('duplicate-app')) {
        rethrow;
      }
    }

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Setup Firebase Messaging: request permissions and get token.
  Future<void> _setupMessaging() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission
    _notificationSettings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    _permissionRequested = true;
    _hasPermission = _notificationSettings?.authorizationStatus == AuthorizationStatus.authorized ||
        _notificationSettings?.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('[Notifications] Permission: ${_notificationSettings?.authorizationStatus}');

    if (!_hasPermission) return;

    // Get FCM token
    await _acquireFcmToken(messaging);

    // Setup listeners
    _setupListeners(messaging);
  }

  /// Acquire FCM token with retry logic for iOS APNS token availability.
  Future<void> _acquireFcmToken(FirebaseMessaging messaging) async {
    // On iOS, we need to wait for APNS token to be available
    if (Platform.isIOS) {
      for (int attempt = 0; attempt < _maxApnsRetries; attempt++) {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('[Notifications] APNS token acquired');
          break;
        }

        debugPrint('[Notifications] Waiting for APNS token (${attempt + 1}/$_maxApnsRetries)');
        await Future.delayed(_apnsRetryDelay);
      }
    }

    try {
      _fcmToken = await messaging.getToken();
      debugPrint('[Notifications] FCM token acquired: ${_fcmToken != null}');

      // Debug: Log app info
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        debugPrint('[Notifications] === DEBUG INFO ===');
        debugPrint('[Notifications] Bundle ID: ${packageInfo.packageName}');
        debugPrint('[Notifications] App Name: ${packageInfo.appName}');
        debugPrint('[Notifications] Version: ${packageInfo.version}');
        debugPrint('[Notifications] Firebase Project: ${Firebase.app().options.projectId}');
        debugPrint('[Notifications] Firebase App ID (iOS): ${Firebase.app().options.appId}');
        debugPrint('[Notifications] Token (first 50): ${_fcmToken?.substring(0, 50)}...');
        debugPrint('[Notifications] ==================');
      } catch (e) {
        debugPrint('[Notifications] Could not get package info: $e');
      }
    } catch (e) {
      debugPrint('[Notifications] Error getting FCM token: $e');
    }
  }

  /// Setup message and token refresh listeners.
  void _setupListeners(FirebaseMessaging messaging) {
    // Token refresh
    messaging.onTokenRefresh.listen(_handleTokenRefresh);

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification taps (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check if app was opened from notification
    messaging.getInitialMessage().then((message) {
      if (message != null) _handleMessageOpenedApp(message);
    });
  }

  /// Handle FCM token refresh.
  void _handleTokenRefresh(String newToken) {
    debugPrint('[Notifications] Token refreshed');

    final oldToken = _fcmToken;
    _fcmToken = newToken;

    // Re-register with backend
    if (oldToken != null && oldToken != newToken) {
      _unregisterToken(oldToken);
    }
    _registerToken(newToken);

    notifyListeners();
  }

  /// Handle foreground message.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[Notifications] Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification != null) {
      InAppNotificationController().show(
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        onTap: () {
          // Handle notification tap - navigate based on message data
          _handleNotificationTap(message.data);
        },
      );
    }
  }

  /// Handle notification tap action
  void _handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('[Notifications] Notification tapped with data: $data');
    // TODO: Implement navigation based on data['type'] or other fields
  }

  /// Handle notification tap when app was in background.
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[Notifications] Opened from notification: ${message.data}');
    // TODO: Handle navigation based on message data
  }

  /// Register FCM token with backend after user login.
  Future<void> registerTokenAfterLogin() async {
    if (_fcmToken == null || !_hasPermission) {
      debugPrint('[Notifications] Cannot register: token=${_fcmToken != null}, permission=$_hasPermission');
      return;
    }

    try {
      await _registerToken(_fcmToken!);
      await loadSettings();
    } catch (e) {
      debugPrint('[Notifications] Error registering token: $e');
    }
  }

  /// Register token with backend.
  Future<void> _registerToken(String token) async {
    try {
      await _apiService.post('/notifications/token', data: {'token': token});
      debugPrint('[Notifications] Token registered with backend');
    } catch (e) {
      debugPrint('[Notifications] Error registering token: $e');
    }
  }

  /// Unregister token from backend.
  Future<void> _unregisterToken(String token) async {
    try {
      await _apiService.delete('/notifications/token/$token');
      debugPrint('[Notifications] Token unregistered');
    } catch (e) {
      debugPrint('[Notifications] Error unregistering token: $e');
    }
  }

  /// Unregister token on user logout.
  Future<void> unregisterTokenOnLogout() async {
    if (_fcmToken == null) return;

    try {
      await _unregisterToken(_fcmToken!);
    } catch (e) {
      debugPrint('[Notifications] Error unregistering on logout: $e');
    }
  }

  /// Load notification settings from backend.
  Future<void> loadSettings() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>('/notifications/settings');
      _enabled = response['enabled'] ?? false;
      _priceChangeThreshold = response['priceChangeThreshold'] ?? 5;
      _quietHoursStart = response['quietHoursStart'];
      _quietHoursEnd = response['quietHoursEnd'];
      _alertAssets = (response['alertAssets'] as List?)
              ?.map((a) => a.toString().toUpperCase())
              .toList() ??
          const [];
      notifyListeners();
    } catch (e) {
      debugPrint('[Notifications] Error loading settings: $e');
    }
  }

  /// Update notification settings on backend.
  Future<void> updateSettings({
    required bool enabled,
    required int priceChangeThreshold,
    String? quietHoursStart,
    String? quietHoursEnd,
    List<String>? alertAssets,
  }) async {
    final assets = alertAssets ?? _alertAssets;

    await _apiService.put('/notifications/settings', data: {
      'enabled': enabled,
      'priceChangeThreshold': priceChangeThreshold,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'alertAssets': assets,
    });

    _enabled = enabled;
    _priceChangeThreshold = priceChangeThreshold;
    _quietHoursStart = quietHoursStart;
    _quietHoursEnd = quietHoursEnd;
    _alertAssets = assets;
    notifyListeners();
  }

  /// Toggle notifications enabled/disabled.
  Future<void> toggleEnabled(bool value) async {
    await updateSettings(
      enabled: value,
      priceChangeThreshold: _priceChangeThreshold,
      quietHoursStart: _quietHoursStart,
      quietHoursEnd: _quietHoursEnd,
    );
  }

  /// Set price change threshold for alerts.
  Future<void> setPriceChangeThreshold(int value) async {
    await updateSettings(
      enabled: _enabled,
      priceChangeThreshold: value,
      quietHoursStart: _quietHoursStart,
      quietHoursEnd: _quietHoursEnd,
    );
  }

  /// Set quiet hours for notifications.
  Future<void> setQuietHours(String? start, String? end) async {
    await updateSettings(
      enabled: _enabled,
      priceChangeThreshold: _priceChangeThreshold,
      quietHoursStart: start,
      quietHoursEnd: end,
    );
  }

  /// Sumar o sacar un activo de los que avisan.
  ///
  /// Pinta el cambio antes de que la API conteste y lo revierte si falla: son
  /// muchos interruptores en una lista y esperar el viaje de red en cada uno
  /// los hace sentir trabados.
  Future<void> setAssetFollowed(String asset, bool followed) async {
    final upper = asset.toUpperCase();
    final previous = List<String>.from(_alertAssets);

    final next = List<String>.from(_alertAssets)..remove(upper);
    if (followed) next.add(upper);

    _alertAssets = next;
    notifyListeners();

    try {
      await updateSettings(
        enabled: _enabled,
        priceChangeThreshold: _priceChangeThreshold,
        quietHoursStart: _quietHoursStart,
        quietHoursEnd: _quietHoursEnd,
        alertAssets: next,
      );
    } catch (e) {
      debugPrint('[Notifications] No se pudo guardar la selección: $e');
      _alertAssets = previous;
      notifyListeners();
      rethrow;
    }
  }
}
