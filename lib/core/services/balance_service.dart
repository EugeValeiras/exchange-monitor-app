import 'package:flutter/foundation.dart';
import '../models/balance.dart';
import 'api_service.dart';

class BalanceService extends ChangeNotifier {
  final ApiService _apiService;

  ConsolidatedBalance? _balance;
  bool _isLoading = false;
  String? _error;

  BalanceService(this._apiService);

  ConsolidatedBalance? get balance => _balance;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _balance != null;

  double get totalValueUsd => _balance?.totalValueUsd ?? 0;
  double? get change24h => _balance?.change24h;
  double? get changeUsd24h => _balance?.changeUsd24h;
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
}
