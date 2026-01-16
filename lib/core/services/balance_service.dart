import 'package:flutter/foundation.dart';
import '../models/balance.dart';
import 'api_service.dart';
import 'price_service.dart';

class BalanceService extends ChangeNotifier {
  final ApiService _apiService;
  PriceService? _priceService;

  ConsolidatedBalance? _balance;
  bool _isLoading = false;
  String? _error;

  // Cache for recalculated values based on real-time prices
  double? _calculatedTotalValueUsd;
  double? _calculatedChange24h;
  double? _calculatedChangeUsd24h;

  BalanceService(this._apiService);

  /// Set the price service and listen to price changes
  void setPriceService(PriceService priceService) {
    if (_priceService != null) return; // Already set
    _priceService = priceService;
    _priceService!.addListener(_onPriceUpdate);
  }

  void _onPriceUpdate() {
    if (_balance != null && _balance!.byAsset.isNotEmpty) {
      _recalculateWithCurrentPrices();
      notifyListeners();
    }
  }

  /// Recalculate balance values using current real-time prices
  void _recalculateWithCurrentPrices() {
    if (_balance == null || _priceService == null) return;

    double totalValue = 0;
    double totalCurrentValue = 0;
    double totalPreviousValue = 0;

    for (final asset in _balance!.byAsset) {
      // Get current price from PriceService
      final currentPrice = _priceService!.getPriceByAsset(asset.asset);
      final change24h = _priceService!.getChange24hByAsset(asset.asset);

      if (currentPrice != null) {
        final assetValue = asset.total * currentPrice;
        totalValue += assetValue;

        // Calculate 24h change contribution
        if (change24h != null) {
          final previousValue = assetValue / (1 + change24h / 100);
          totalCurrentValue += assetValue;
          totalPreviousValue += previousValue;
        } else {
          // No change data, assume 0% change
          totalCurrentValue += assetValue;
          totalPreviousValue += assetValue;
        }
      } else if (asset.valueUsd != null) {
        // Fallback to cached value from API
        totalValue += asset.valueUsd!;
        totalCurrentValue += asset.valueUsd!;
        totalPreviousValue += asset.valueUsd!;
      }
    }

    _calculatedTotalValueUsd = totalValue;

    // Calculate overall percentage change
    if (totalPreviousValue > 0) {
      _calculatedChange24h =
          ((totalCurrentValue - totalPreviousValue) / totalPreviousValue) * 100;
      _calculatedChangeUsd24h = totalCurrentValue - totalPreviousValue;
    }
  }

  ConsolidatedBalance? get balance => _balance;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _balance != null;

  /// Returns the total value, preferring real-time calculated value
  double get totalValueUsd => _calculatedTotalValueUsd ?? _balance?.totalValueUsd ?? 0;

  /// Returns the 24h change percentage, preferring real-time calculated value
  double? get change24h => _calculatedChange24h ?? _balance?.change24h;

  /// Returns the 24h change in USD, preferring real-time calculated value
  double? get changeUsd24h => _calculatedChangeUsd24h ?? _balance?.changeUsd24h;
  int get exchangeCount => _balance?.exchangeCount ?? 0;
  int get assetCount => _balance?.assetCount ?? 0;
  List<AssetBalance> get assets => _balance?.byAsset ?? [];
  List<ExchangeBalance> get exchanges => _balance?.byExchange ?? [];

  Future<void> loadBalance() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get<Map<String, dynamic>>('/balances');
      _balance = ConsolidatedBalance.fromJson(response);
      _error = null;

      // Subscribe to prices for all assets and do initial calculation
      _subscribeToAssetPrices();
      _recalculateWithCurrentPrices();
    } on ApiException catch (e) {
      _error = e.message;
      if (kDebugMode) {
        print('Error loading balance: $e');
      }
    } catch (e) {
      _error = 'Failed to load balance';
      if (kDebugMode) {
        print('Error loading balance: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to price updates for all assets in the balance
  void _subscribeToAssetPrices() {
    if (_balance == null || _priceService == null) return;

    final symbols = _balance!.byAsset
        .map((a) => '${a.asset}/USDT')
        .where((s) => !s.startsWith('USDT/') && !s.startsWith('USD/'))
        .toList();

    if (symbols.isNotEmpty) {
      _priceService!.subscribe(symbols);
    }
  }

  Future<void> refresh() async {
    await loadBalance();
  }

  List<AssetBalance> getAssetsByExchange(String? exchange) {
    if (exchange == null || exchange.isEmpty) {
      return assets;
    }
    return assets.where((a) => a.exchanges.contains(exchange)).toList();
  }

  List<AssetBalance> get sortedAssetsByValue {
    final sorted = List<AssetBalance>.from(assets);
    sorted.sort((a, b) => (b.valueUsd ?? 0).compareTo(a.valueUsd ?? 0));
    return sorted;
  }

  List<AssetBalance> get topAssets {
    return sortedAssetsByValue.take(5).toList();
  }

  @override
  void dispose() {
    _priceService?.removeListener(_onPriceUpdate);
    super.dispose();
  }
}
