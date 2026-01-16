import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';
import 'balance_service.dart';
import 'chart_service.dart';

class WidgetService {
  static const String appGroupId = 'group.com.eugeniovaleiras.exchangeMonitor';
  static const String widgetName = 'ExchangeWidget';

  final BalanceService _balanceService;
  final ChartService _chartService;

  WidgetService(this._balanceService, this._chartService);

  Future<void> updateWidget() async {
    try {
      // Prepare widget data
      final widgetData = {
        'totalBalance': _balanceService.totalValueUsd,
        'change24hPercent': _balanceService.change24h ?? 0.0,
        'change24hUsd': _balanceService.changeUsd24h ?? 0.0,
        'chartData': _chartService.dataPoints.take(20).toList(),
        'assets': _balanceService.topAssets.take(3).map((asset) => {
          'symbol': asset.asset,
          'name': _getAssetName(asset.asset),
          'price': asset.priceUsd ?? 0.0,
          'change24h': asset.change24h ?? 0.0,
          'sparkline': _generateSparkline(asset.priceUsd ?? 0.0, asset.change24h ?? 0.0),
        }).toList(),
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
}
