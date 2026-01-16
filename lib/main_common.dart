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

Future<void> mainCommon() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(apiService),
        ),
        ChangeNotifierProvider<BalanceService>(
          create: (_) => BalanceService(apiService),
        ),
        ChangeNotifierProvider<ChartService>(
          create: (_) => ChartService(apiService),
        ),
        ChangeNotifierProvider<PriceService>(
          create: (_) => PriceService(),
        ),
        ChangeNotifierProvider<TransactionService>(
          create: (_) => TransactionService(apiService),
        ),
      ],
      child: const ExchangeMonitorApp(),
    ),
  );
}
