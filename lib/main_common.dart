import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/balance_service.dart';
import 'core/services/chart_service.dart';
import 'core/services/price_service.dart';
import 'core/services/transaction_service.dart';
import 'core/services/favorites_service.dart';
import 'core/services/widget_service.dart';
import 'core/services/notification_service.dart';

Future<void> mainCommon() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize widget service
  await WidgetService.initialize();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0E11),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Create services
  final apiService = ApiService();

  // Initialize notification service
  final notificationService = NotificationService(apiService);
  await notificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(apiService),
        ),
        ChangeNotifierProvider<PriceService>(
          create: (_) => PriceService(),
        ),
        ChangeNotifierProxyProvider<PriceService, BalanceService>(
          create: (_) => BalanceService(apiService),
          update: (_, priceService, balanceService) {
            balanceService!.setPriceService(priceService);
            return balanceService;
          },
        ),
        ChangeNotifierProvider<ChartService>(
          create: (_) => ChartService(apiService),
        ),
        ChangeNotifierProvider<TransactionService>(
          create: (_) => TransactionService(apiService),
        ),
        ChangeNotifierProvider<FavoritesService>(
          create: (_) => FavoritesService(apiService),
        ),
        ChangeNotifierProvider<NotificationService>.value(
          value: notificationService,
        ),
      ],
      child: const ExchangeMonitorApp(),
    ),
  );
}
