import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';
import 'balance_service.dart';
import 'chart_service.dart';
import 'price_service.dart';
import 'favorites_service.dart';

class WidgetService {
  static const String appGroupId = 'group.com.eugeniovaleiras.exchangeMonitor';
  static const String widgetName = 'ExchangeWidget';

  final BalanceService _balanceService;
  final ChartService _chartService;
  final PriceService? _priceService;
  final FavoritesService? _favoritesService;

  WidgetService(this._balanceService, this._chartService, [this._priceService, this._favoritesService]);

  Future<void> updateWidget() async {
    try {
      // Prepare widget data
      final widgetData = {
        'totalBalance': _balanceService.totalValueUsd,
        'change24hPercent': _balanceService.change24h ?? 0.0,
        'change24hUsd': _balanceService.changeUsd24h ?? 0.0,
        'chartData': _chartService.dataPoints,
        'assets': _getMarketAssets(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // Save data to App Group
      await HomeWidget.saveWidgetData<String>(
        'widgetData',
        jsonEncode(widgetData),
      );

      // Request widget update
      await HomeWidget.updateWidget(
        iOSName: widgetName,
        qualifiedAndroidName: 'com.eugeniovaleiras.exchangeMonitor.ExchangeWidget',
      );

      if (kDebugMode) {
        print('Widget updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating widget: $e');
      }
    }
  }

  List<Map<String, dynamic>> _getMarketAssets() {
    // Get first 3 favorites from FavoritesService, fallback to defaults
    final favoriteSymbols = _favoritesService?.getTopFavorites(3) ??
        (_favoritesService?.hasFavorites == true ? _favoritesService!.favorites.take(3).toList() : ['BTC', 'ETH', 'SOL']);

    return favoriteSymbols.map((symbol) {
      // Try to find the asset in balance service
      final asset = _balanceService.assets.where((a) => a.asset.toUpperCase() == symbol).firstOrNull;

      // Get price and change from PriceService or asset
      final price = _priceService?.getPriceByAsset(symbol) ?? asset?.priceUsd ?? 0.0;
      final change24h = _priceService?.getChange24hByAsset(symbol) ?? asset?.change24h ?? 0.0;

      // Get real sparkline data from ChartService (24h data by asset)
      final sparkline = _getAssetSparkline(symbol) ?? _generateSparkline(price, change24h);

      return {
        'symbol': symbol,
        'name': _getAssetName(symbol),
        'price': price,
        'change24h': change24h,
        'sparkline': sparkline,
      };
    }).toList();
  }

  List<double>? _getAssetSparkline(String symbol) {
    // Get asset chart data from ChartService (24h timeframe)
    final chartDataByAsset = _chartService.chartDataByAsset;
    if (chartDataByAsset == null) return null;

    // Find the asset data matching the symbol
    final assetData = chartDataByAsset.assetData
        .where((ad) => ad.asset.toUpperCase() == symbol.toUpperCase())
        .firstOrNull;

    if (assetData == null || assetData.data.isEmpty) return null;

    // Downsample to 24 points for sparkline
    final data = assetData.data;
    if (data.length <= 24) return data;

    final step = data.length / 24;
    final sparkline = <double>[];
    for (var i = 0; i < 24; i++) {
      final index = (i * step).floor().clamp(0, data.length - 1);
      sparkline.add(data[index]);
    }
    // Ensure last point is the actual last value
    sparkline[23] = data.last;
    return sparkline;
  }

  String _getAssetName(String symbol) {
    const assetNames = {
      'BTC': 'Bitcoin',
      'ETH': 'Ethereum',
      'NEXO': 'NEXO Token',
      'SOL': 'Solana',
      'ADA': 'Cardano',
      'XRP': 'Ripple',
      'DOGE': 'Dogecoin',
      'DOT': 'Polkadot',
      'MATIC': 'Polygon',
      'SHIB': 'Shiba Inu',
      'TRX': 'Tron',
      'AVAX': 'Avalanche',
      'LINK': 'Chainlink',
      'UNI': 'Uniswap',
      'ATOM': 'Cosmos',
      'LTC': 'Litecoin',
      'ETC': 'Ethereum Classic',
      'XLM': 'Stellar',
      'ALGO': 'Algorand',
      'VET': 'VeChain',
      'USDT': 'Tether',
      'USDC': 'USD Coin',
      'BUSD': 'Binance USD',
      'DAI': 'Dai',
      'MON': 'Monad',
      'PEPE': 'Pepe',
      'ARB': 'Arbitrum',
      'OP': 'Optimism',
    };
    return assetNames[symbol.toUpperCase()] ?? symbol;
  }

  List<double> _generateSparkline(double currentPrice, double change24h) {
    // Generate a simple sparkline based on current price and 24h change
    final List<double> sparkline = [];
    final startPrice = currentPrice / (1 + change24h / 100);
    final priceChange = currentPrice - startPrice;

    for (int i = 0; i < 6; i++) {
      final progress = i / 5.0;
      // Add some variance to make it look more natural
      final variance = (i % 2 == 0 ? 0.02 : -0.01) * priceChange;
      sparkline.add(startPrice + (priceChange * progress) + variance);
    }
    sparkline[5] = currentPrice; // Ensure last point is current price

    return sparkline;
  }

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  /// Save auth token to App Group so widget can fetch data directly
  static Future<void> saveAuthToken(String? token) async {
    if (token != null) {
      await HomeWidget.saveWidgetData<String>('authToken', token);
    }
  }

  /// Debug method to check widget status
  static Future<Map<String, dynamic>> getWidgetDebugInfo() async {
    final lastTimelineCall = await HomeWidget.getWidgetData<double>('lastTimelineCall');
    final lastFetchSuccess = await HomeWidget.getWidgetData<bool>('lastFetchSuccess');
    final lastFetchTime = await HomeWidget.getWidgetData<double>('lastFetchTime');
    final lastFetchError = await HomeWidget.getWidgetData<String>('lastFetchError');
    final balanceError = await HomeWidget.getWidgetData<String>('balanceError');
    final authToken = await HomeWidget.getWidgetData<String>('authToken');
    final debugToken = await HomeWidget.getWidgetData<String>('debugToken');
    final pushDataReceivedAt = await HomeWidget.getWidgetData<double>('pushDataReceivedAt');
    final refreshTrigger = await HomeWidget.getWidgetData<double>('refreshTrigger');

    final now = DateTime.now().millisecondsSinceEpoch / 1000;

    String formatTimestamp(double? ts) {
      if (ts == null) return 'never';
      final date = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
      final ago = ((now - ts) / 60).toStringAsFixed(1);
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')} (${ago}m ago)';
    }

    return {
      'lastTimelineCall': formatTimestamp(lastTimelineCall),
      'lastFetchTime': formatTimestamp(lastFetchTime),
      'lastFetchSuccess': lastFetchSuccess ?? 'unknown',
      'lastFetchError': lastFetchError ?? 'none',
      'balanceError': balanceError ?? 'none',
      'pushDataReceivedAt': formatTimestamp(pushDataReceivedAt),
      'refreshTrigger': formatTimestamp(refreshTrigger),
      'hasAuthToken (Flutter saved)': authToken != null && authToken.isNotEmpty,
      'flutterTokenFull': authToken ?? 'null',
      'widgetReadToken': debugToken ?? 'widget never read token',
    };
  }

  /// Print widget debug info to console
  static Future<void> printDebugInfo() async {
    final info = await getWidgetDebugInfo();
    debugPrint('=== Widget Debug Info ===');
    info.forEach((key, value) {
      debugPrint('  $key: $value');
    });
    debugPrint('========================');
  }
}
