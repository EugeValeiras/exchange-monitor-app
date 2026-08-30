import 'package:flutter/foundation.dart';
import '../models/chart_data.dart';
import '../models/transaction.dart';
import '../utils/formatters.dart';
import 'api_service.dart';

/// Un movimiento de capital dentro del período del gráfico: plata que entró o
/// salió por mano del usuario, no resultado de mercado.
class CapitalEvent {
  final DateTime timestamp;
  final String asset;
  final double amount;
  final bool isDeposit;

  /// Valor en dólares AL MOMENTO del movimiento. Null cuando la transacción no
  /// trae precio: entonces el evento se muestra pero no se suma, en vez de
  /// inventar una cifra con el precio de hoy.
  final double? usdValue;

  const CapitalEvent({
    required this.timestamp,
    required this.asset,
    required this.amount,
    required this.isDeposit,
    this.usdValue,
  });
}

class ChartService extends ChangeNotifier {
  final ApiService _apiService;

  ChartDataResponse? _chartData;
  ChartDataByAssetResponse? _chartDataByAsset;
  ChartTimeframe _selectedTimeframe = ChartTimeframe.h24;
  bool _isLoading = false;
  String? _error;
  final Set<String> _selectedAssets = {};
  List<CapitalEvent> _capitalEvents = const [];

  ChartService(this._apiService);

  ChartDataResponse? get chartData => _chartData;
  ChartDataByAssetResponse? get chartDataByAsset => _chartDataByAsset;
  ChartTimeframe get selectedTimeframe => _selectedTimeframe;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _chartData != null || _chartDataByAsset != null;
  Set<String> get selectedAssets => _selectedAssets;
  bool get hasAssetFilter => _selectedAssets.isNotEmpty;

  double get changeUsd => _chartData?.changeUsd ?? _chartDataByAsset?.changeUsd ?? 0;
  double get changePercent => _chartData?.changePercent ?? _chartDataByAsset?.changePercent ?? 0;

  /// Movimientos de capital dentro del período dibujado.
  List<CapitalEvent> get capitalEvents => _capitalEvents;

  /// Neto de capital del período en dólares, o null si algún movimiento no se
  /// pudo valorizar (entonces la UI dice cuántos hubo, sin cifra).
  double? get netCapitalUsd {
    if (_capitalEvents.isEmpty) return 0;
    double net = 0;
    for (final e in _capitalEvents) {
      if (e.usdValue == null) return null;
      net += e.isDeposit ? e.usdValue! : -e.usdValue!;
    }
    return net;
  }

  /// Primer y último valor de la serie: con eso el número grande puede mostrar
  /// el valor comparado del período, en vez de quedarse siempre en "ahora".
  double? get startValue {
    final values = dataPoints;
    return values.isEmpty ? null : values.first;
  }

  double? get endValue {
    final values = dataPoints;
    return values.isEmpty ? null : values.last;
  }

  DateTime? get periodStart {
    final points = getChartPoints();
    return points.isEmpty ? null : points.first.timestamp;
  }

  List<double> get dataPoints {
    // If we have filtered assets and asset data, calculate the sum of selected assets
    if (_selectedAssets.isNotEmpty && _chartDataByAsset != null) {
      return _getFilteredDataPoints();
    }
    return _chartDataByAsset?.totalData ?? _chartData?.data ?? [];
  }

  List<double> _getFilteredDataPoints() {
    final assetData = _chartDataByAsset?.assetData ?? [];
    if (assetData.isEmpty) return _chartDataByAsset?.totalData ?? [];

    // Filter only selected assets (case-insensitive)
    final selectedLower = _selectedAssets.map((a) => a.toLowerCase()).toSet();
    final selectedAssetData = assetData
        .where((ad) => selectedLower.contains(ad.asset.toLowerCase()))
        .toList();

    if (selectedAssetData.isEmpty) return _chartDataByAsset?.totalData ?? [];

    // Sum up values for each timestamp
    final numPoints = selectedAssetData.first.data.length;
    final result = List<double>.filled(numPoints, 0);

    for (final ad in selectedAssetData) {
      for (var i = 0; i < ad.data.length && i < numPoints; i++) {
        result[i] += ad.data[i];
      }
    }

    return result;
  }

  List<String> get labels => _chartDataByAsset?.labels ?? _chartData?.labels ?? [];

  Future<void> loadChartData({
    ChartTimeframe? timeframe,
    List<String>? assets,
  }) async {
    if (timeframe != null) {
      _selectedTimeframe = timeframe;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // For 24h and 7d, use the by-asset endpoint to get asset breakdown
      if (_selectedTimeframe == ChartTimeframe.h24 ||
          _selectedTimeframe == ChartTimeframe.d7) {
        final queryParams = <String, dynamic>{
          'timeframe': _selectedTimeframe.value,
        };
        if (assets != null && assets.isNotEmpty) {
          queryParams['assets'] = assets.join(',');
        }

        final response = await _apiService.get<Map<String, dynamic>>(
          '/snapshots/chart-data-by-asset',
          queryParameters: queryParams,
        );
        _chartDataByAsset = ChartDataByAssetResponse.fromJson(response);
        _chartData = null;
      } else {
        // For 1m and 1y, use the simple endpoint
        final response = await _apiService.get<Map<String, dynamic>>(
          '/snapshots/chart-data',
          queryParameters: {'timeframe': _selectedTimeframe.value},
        );
        _chartData = ChartDataResponse.fromJson(response);
        _chartDataByAsset = null;
      }
      _error = null;
      await _loadCapitalEvents();
    } on ApiException catch (e) {
      _error = e.message;
      if (kDebugMode) {
        print('Error loading chart data: $e');
      }
    } catch (e) {
      _error = 'Failed to load chart data';
      if (kDebugMode) {
        print('Error loading chart data: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Trae los depósitos y retiros del período para poder separar, en la
  /// pantalla, lo que se movió por mercado de lo que entró o salió por mano
  /// del usuario. Antes la curva mezclaba las dos cosas y un depósito se leía
  /// como una ganancia.
  Future<void> _loadCapitalEvents() async {
    final start = periodStart;
    if (start == null) {
      _capitalEvents = const [];
      return;
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/transactions',
        queryParameters: {
          'types': 'deposit,withdrawal',
          'startDate': start.toIso8601String(),
          'limit': '200',
        },
      );

      final page = PaginatedTransactions.fromJson(response);
      _capitalEvents = page.data.map((t) {
        final isDeposit = t.type == TransactionType.deposit;
        double? usd;
        if (isDollarQuote(t.asset)) {
          usd = t.amount.abs();
        } else if (t.price != null && (t.priceAsset == null || isDollarQuote(t.priceAsset!))) {
          usd = t.amount.abs() * t.price!;
        }
        return CapitalEvent(
          timestamp: t.timestamp,
          asset: t.asset,
          amount: t.amount.abs(),
          isDeposit: isDeposit,
          usdValue: usd,
        );
      }).toList();
    } catch (e) {
      // El gráfico se dibuja igual sin esto; sólo se pierde la distinción.
      _capitalEvents = const [];
      if (kDebugMode) print('Error cargando movimientos de capital: $e');
    }
  }

  void setTimeframe(ChartTimeframe timeframe) {
    if (_selectedTimeframe != timeframe) {
      loadChartData(timeframe: timeframe);
    }
  }

  void toggleAsset(String asset) {
    if (_selectedAssets.contains(asset)) {
      _selectedAssets.remove(asset);
    } else {
      _selectedAssets.add(asset);
    }
    // Just notify - filtering is done client-side in dataPoints getter
    notifyListeners();
  }

  void clearAssetFilter() {
    if (_selectedAssets.isNotEmpty) {
      _selectedAssets.clear();
      notifyListeners();
    }
  }

  bool isAssetSelected(String asset) => _selectedAssets.contains(asset);

  List<String> get availableAssets => _chartDataByAsset?.availableAssets ?? [];

  // Get the last filtered value (for the "current" point on chart)
  double? getFilteredLastValue() {
    if (_selectedAssets.isEmpty) return null;
    final filtered = _getFilteredDataPoints();
    return filtered.isNotEmpty ? filtered.last : null;
  }

  // Get the first filtered value (for 24h change calculation)
  double? getFilteredFirstValue() {
    if (_selectedAssets.isEmpty) return null;
    final filtered = _getFilteredDataPoints();
    return filtered.isNotEmpty ? filtered.first : null;
  }

  // Get the filtered 24h change in percentage
  double? getFilteredChange24hPercent() {
    if (_selectedAssets.isEmpty) return null;
    final firstValue = getFilteredFirstValue();
    final lastValue = getFilteredLastValue();
    if (firstValue == null || lastValue == null || firstValue == 0) return null;
    return ((lastValue - firstValue) / firstValue) * 100;
  }

  // Get the filtered 24h change in USD
  double? getFilteredChange24hUsd() {
    if (_selectedAssets.isEmpty) return null;
    final firstValue = getFilteredFirstValue();
    final lastValue = getFilteredLastValue();
    if (firstValue == null || lastValue == null) return null;
    return lastValue - firstValue;
  }

  List<ChartPoint> getChartPoints() {
    final points = <ChartPoint>[];
    final dataLabels = labels;
    final values = dataPoints;

    for (var i = 0; i < dataLabels.length && i < values.length; i++) {
      points.add(ChartPoint(
        timestamp: DateTime.tryParse(dataLabels[i]) ?? DateTime.now(),
        value: values[i],
      ));
    }
    return points;
  }
}
