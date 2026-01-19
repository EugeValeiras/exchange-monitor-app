import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/price_service.dart';
import 'core/services/balance_service.dart';
import 'core/services/chart_service.dart';
import 'core/services/transaction_service.dart';
import 'core/services/favorites_service.dart';
import 'core/services/widget_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'shared/widgets/app_scaffold.dart';
import 'shared/widgets/logo_loader.dart';
import 'shared/widgets/notification_permission_sheet.dart';
import 'shared/widgets/in_app_notification.dart';

class ExchangeMonitorApp extends StatefulWidget {
  const ExchangeMonitorApp({super.key});

  @override
  State<ExchangeMonitorApp> createState() => _ExchangeMonitorAppState();
}

class _ExchangeMonitorAppState extends State<ExchangeMonitorApp> with WidgetsBindingObserver {
  static const _notificationSheetShownKey = 'notification_permission_sheet_shown';

  bool _servicesInitialized = false;
  bool _wasAuthenticated = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize auth on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthService>().initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Only update widget when app goes to background
    if (state == AppLifecycleState.paused && _servicesInitialized) {
      _updateWidget();
    }
  }

  void _updateWidget() {
    final authService = context.read<AuthService>();
    if (!authService.isAuthenticated) return;

    final balanceService = context.read<BalanceService>();
    final chartService = context.read<ChartService>();
    final priceService = context.read<PriceService>();
    final favoritesService = context.read<FavoritesService>();

    final widgetService = WidgetService(balanceService, chartService, priceService, favoritesService);
    widgetService.updateWidget();
  }

  void _initializeServices(BuildContext context) async {
    if (_servicesInitialized) return;
    _servicesInitialized = true;

    final authService = context.read<AuthService>();
    final token = await authService.getStoredToken();

    if (token != null) {
      // Save token to App Group for widget background fetch
      await WidgetService.saveAuthToken(token);

      // Initialize PriceService with token and connect
      final priceService = context.read<PriceService>();
      priceService.setAuthToken(token);
      priceService.connect();

      // Load initial data
      final balanceService = context.read<BalanceService>();
      final chartService = context.read<ChartService>();
      final favoritesService = context.read<FavoritesService>();

      await Future.wait([
        balanceService.loadBalance(),
        chartService.loadChartData(),
        favoritesService.loadFavorites(),
      ]);

      context.read<TransactionService>().refresh();

      // Show notification permission sheet if not shown before
      await _showNotificationPermissionIfNeeded(context);

      // Debug: print widget status
      debugPrint('>>> PRINTING WIDGET DEBUG INFO <<<');
      await WidgetService.printDebugInfo();
    }
  }

  Future<void> _showNotificationPermissionIfNeeded(BuildContext context) async {
    final notificationService = context.read<NotificationService>();

    // Skip if already has permission and token
    if (notificationService.hasPermission) {
      await notificationService.registerTokenAfterLogin();
      return;
    }

    // Check if we've shown the sheet before
    final prefs = await SharedPreferences.getInstance();
    final sheetShown = prefs.getBool(_notificationSheetShownKey) ?? false;

    if (sheetShown) {
      // Sheet was shown before - try to setup messaging anyway
      // (iOS won't show dialog again if already granted)
      final granted = await notificationService.requestPermissionAndSetup();
      if (granted) {
        await notificationService.registerTokenAfterLogin();
      }
      return;
    }

    // Get the navigator context
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;

    // Small delay to ensure the UI is ready
    await Future.delayed(const Duration(milliseconds: 500));

    // Show the permission bottom sheet
    final accepted = await NotificationPermissionSheet.show(navigatorContext);

    // Mark as shown
    await prefs.setBool(_notificationSheetShownKey, true);

    if (accepted) {
      // User accepted, request native permission
      final granted = await notificationService.requestPermissionAndSetup();
      if (granted) {
        await notificationService.registerTokenAfterLogin();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Exchange Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        // Wrap the entire app with in-app notification overlay
        return InAppNotificationOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Consumer<AuthService>(
        builder: (context, authService, _) {
          // Show loading while checking auth
          if (!authService.isInitialized) {
            return const Scaffold(
              backgroundColor: AppColors.bgPrimary,
              body: Center(
                child: LogoLoader(
                  size: 120,
                  showText: false,
                ),
              ),
            );
          }

          // Show login if not authenticated
          if (!authService.isAuthenticated) {
            // Cleanup on logout
            if (_wasAuthenticated) {
              _wasAuthenticated = false;
              _servicesInitialized = false;
              // Unregister push token on logout
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<NotificationService>().unregisterTokenOnLogout();
              });
            }
            return const LoginScreen();
          }
          _wasAuthenticated = true;

          // Initialize services when authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeServices(context);
          });

          // Show main app
          return const AppScaffold();
        },
      ),
    );
  }
}
