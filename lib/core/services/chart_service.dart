import 'package:flutter/foundation.dart';
import '../models/chart_data.dart';
import 'api_service.dart';

class ChartService extends ChangeNotifier {
  final ApiService _apiService;

  ChartDataResponse? _chartData;
  ChartDataByAssetResponse? _chartDataByAsset;
  ChartTimeframe _selectedTimeframe = ChartTimeframe.h24;
  bool _isLoading = false;
  String? _error;
  Set<String> _selectedAssets = {};

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
