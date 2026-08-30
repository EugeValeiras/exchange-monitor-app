import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/em_theme.dart';
import 'core/theme/em_tokens.dart';
import 'core/services/auth_service.dart';
import 'core/services/price_service.dart';
import 'core/services/balance_service.dart';
import 'core/services/chart_service.dart';
import 'core/services/transaction_service.dart';
import 'core/services/favorites_service.dart';
import 'core/services/pnl_service.dart';
import 'core/services/widget_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'shared/widgets/app_scaffold.dart';
import 'shared/widgets/logo_loader.dart';
import 'shared/widgets/in_app_notification.dart';

class ExchangeMonitorApp extends StatefulWidget {
  const ExchangeMonitorApp({super.key});

  @override
  State<ExchangeMonitorApp> createState() => _ExchangeMonitorAppState();
}

class _ExchangeMonitorAppState extends State<ExchangeMonitorApp>
    with WidgetsBindingObserver {
  bool _servicesInitialized = false;
  bool _wasAuthenticated = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (state == AppLifecycleState.paused && _servicesInitialized) {
      _updateWidget();
    }
  }

  void _updateWidget() {
    final authService = context.read<AuthService>();
    if (!authService.isAuthenticated) return;

    final widgetService = WidgetService(
      context.read<BalanceService>(),
      context.read<ChartService>(),
      context.read<PriceService>(),
      context.read<FavoritesService>(),
    );
    widgetService.updateWidget();
  }

  void _initializeServices(BuildContext context) async {
    if (_servicesInitialized) return;
    _servicesInitialized = true;

    // Todo lo que se lee del árbol se resuelve ACÁ, antes del primer await:
    // después de uno, el context puede estar desmontado.
    final authService = context.read<AuthService>();
    final priceService = context.read<PriceService>();
    final balanceService = context.read<BalanceService>();
    final chartService = context.read<ChartService>();
    final favoritesService = context.read<FavoritesService>();
    final pnlService = context.read<PnlService>();
    final transactionService = context.read<TransactionService>();
    final notifications = context.read<NotificationService>();

    final token = await authService.getStoredToken();
    if (token == null) return;

    await WidgetService.saveAuthToken(token);

    priceService.setAuthToken(token);
    priceService.connect();

    await Future.wait([
      balanceService.loadBalance(),
      chartService.loadChartData(),
      favoritesService.loadFavorites(),
      pnlService.load(),
    ]);

    if (!mounted) return;
    transactionService.refresh();

    // El permiso de notificaciones NO se pide acá: interrumpía el primer
    // render con una hoja modal antes de que el usuario llegara a ver su
    // cartera, y prometía ajustes ("horarios", "umbral") que la pantalla real
    // no tenía. Se pide en Ajustes → Notificaciones, donde el contexto lo
    // justifica y los controles están a la vista.
    if (notifications.hasPermission) {
      await notifications.registerTokenAfterLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Exchange Monitor',
      debugShowCheckedModeBanner: false,
      theme: EmTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return InAppNotificationOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Consumer<AuthService>(
        builder: (context, authService, _) {
          if (!authService.isInitialized) {
            return const Scaffold(
              backgroundColor: EmColors.bg,
              body: Center(child: LogoLoader(size: 120, showText: false)),
            );
          }

          if (!authService.isAuthenticated) {
            if (_wasAuthenticated) {
              _wasAuthenticated = false;
              _servicesInitialized = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<NotificationService>().unregisterTokenOnLogout();
              });
            }
            return const LoginScreen();
          }
          _wasAuthenticated = true;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeServices(context);
          });

          return const AppScaffold();
        },
      ),
    );
  }
}
