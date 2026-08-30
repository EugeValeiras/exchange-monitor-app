import 'package:equatable/equatable.dart';

enum ChartTimeframe {
  h24('24h'),
  d7('7d'),
  m1('1m'),
  y1('1y');

  final String value;
  const ChartTimeframe(this.value);

  /// Texto del período para la frase del delta: "últimas 24 h", "último mes".
  String get sinceLabel {
    switch (this) {
      case ChartTimeframe.h24:
        return 'últimas 24 h';
      case ChartTimeframe.d7:
        return 'últimos 7 días';
      case ChartTimeframe.m1:
        return 'último mes';
      case ChartTimeframe.y1:
        return 'último año';
    }
  }

  String get label {
    switch (this) {
      case ChartTimeframe.h24:
        return '24H';
      case ChartTimeframe.d7:
        return '7D';
      case ChartTimeframe.m1:
        return '1M';
      case ChartTimeframe.y1:
        return '1A';
    }
  }
}

class ChartDataResponse extends Equatable {
  final List<String> labels;
  final List<double> data;
  final double changeUsd;
  final double changePercent;
  final String timeframe;

  const ChartDataResponse({
    required this.labels,
    required this.data,
    required this.changeUsd,
    required this.changePercent,
    required this.timeframe,
  });

  factory ChartDataResponse.fromJson(Map<String, dynamic> json) {
    return ChartDataResponse(
      labels: (json['labels'] as List<dynamic>).map((e) => e as String).toList(),
      data: (json['data'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      changeUsd: (json['changeUsd'] as num?)?.toDouble() ?? 0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0,
      timeframe: json['timeframe'] as String,
    );
  }

  List<ChartPoint> get points {
    final result = <ChartPoint>[];
    for (var i = 0; i < labels.length && i < data.length; i++) {
      result.add(ChartPoint(
        timestamp: DateTime.tryParse(labels[i]) ?? DateTime.now(),
        value: data[i],
      ));
    }
    return result;
  }

  @override
  List<Object?> get props => [labels, data, changeUsd, changePercent, timeframe];
}

class AssetChartData extends Equatable {
  final String asset;
  final List<double> data;

  const AssetChartData({
    required this.asset,
    required this.data,
  });

  factory AssetChartData.fromJson(Map<String, dynamic> json) {
    return AssetChartData(
      asset: json['asset'] as String,
      data: (json['data'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  @override
  List<Object?> get props => [asset, data];
}

class ChartDataByAssetResponse extends Equatable {
  final List<String> labels;
  final List<double> totalData;
  final List<AssetChartData> assetData;
  final List<String> availableAssets;
  final double changeUsd;
  final double changePercent;
  final String timeframe;

  const ChartDataByAssetResponse({
    required this.labels,
    required this.totalData,
    required this.assetData,
    required this.availableAssets,
    required this.changeUsd,
    required this.changePercent,
    required this.timeframe,
  });

  factory ChartDataByAssetResponse.fromJson(Map<String, dynamic> json) {
    return ChartDataByAssetResponse(
      labels: (json['labels'] as List<dynamic>).map((e) => e as String).toList(),
      totalData: (json['totalData'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      assetData: (json['assetData'] as List<dynamic>?)
              ?.map((e) => AssetChartData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      availableAssets: (json['availableAssets'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      changeUsd: (json['changeUsd'] as num?)?.toDouble() ?? 0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0,
      timeframe: json['timeframe'] as String,
    );
  }

  @override
  List<Object?> get props => [
        labels,
        totalData,
        assetData,
        availableAssets,
        changeUsd,
        changePercent,
        timeframe,
      ];
}

class ChartPoint {
  final DateTime timestamp;
  final double value;

  const ChartPoint({
    required this.timestamp,
    required this.value,
  });
}
