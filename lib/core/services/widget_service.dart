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

      return {
        'symbol': symbol,
        'name': _getAssetName(symbol),
        'price': price,
        'change24h': change24h,
        'sparkline': _generateSparkline(price, change24h),
      };
    }).toList();
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
}
