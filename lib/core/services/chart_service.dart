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

  ChartService(this._apiService);

  ChartDataResponse? get chartData => _chartData;
  ChartDataByAssetResponse? get chartDataByAsset => _chartDataByAsset;
  ChartTimeframe get selectedTimeframe => _selectedTimeframe;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _chartData != null || _chartDataByAsset != null;

  double get changeUsd => _chartData?.changeUsd ?? _chartDataByAsset?.changeUsd ?? 0;
  double get changePercent => _chartData?.changePercent ?? _chartDataByAsset?.changePercent ?? 0;

  List<double> get dataPoints => _chartDataByAsset?.totalData ?? _chartData?.data ?? [];
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

  List<String> get availableAssets => _chartDataByAsset?.availableAssets ?? [];

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
