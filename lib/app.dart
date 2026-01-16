import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/price_service.dart';
import 'core/services/balance_service.dart';
import 'core/services/chart_service.dart';
import 'core/services/transaction_service.dart';
import 'core/services/favorites_service.dart';
import 'core/services/widget_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'shared/widgets/app_scaffold.dart';
import 'shared/widgets/logo_loader.dart';

class ExchangeMonitorApp extends StatefulWidget {
  const ExchangeMonitorApp({super.key});

  @override
  State<ExchangeMonitorApp> createState() => _ExchangeMonitorAppState();
}

class _ExchangeMonitorAppState extends State<ExchangeMonitorApp> with WidgetsBindingObserver {
  bool _servicesInitialized = false;

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
    // Update widget when app comes to foreground
    if (state == AppLifecycleState.resumed && _servicesInitialized) {
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

      // Update iOS widget with latest data
      final widgetService = WidgetService(balanceService, chartService, priceService, favoritesService);
      widgetService.updateWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exchange Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Consumer<AuthService>(
        builder: (context, authService, _) {
          // Show loading while checking auth
          if (!authService.isInitialized) {
            return const Scaffold(
              backgroundColor: AppColors.bgPrimary,
              body: Center(
                child: LogoLoader(
                  size: 120,
                  showText: true,
                  text: 'Cargando...',
                ),
              ),
            );
          }

          // Show login if not authenticated
          if (!authService.isAuthenticated) {
            _servicesInitialized = false; // Reset on logout
            return const LoginScreen();
          }

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
