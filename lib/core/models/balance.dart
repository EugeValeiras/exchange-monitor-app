import 'package:equatable/equatable.dart';

class AssetBalance extends Equatable {
  final String asset;
  final double free;
  final double locked;
  final double total;
  final double? priceUsd;
  final double? valueUsd;
  final double? change24h;
  final List<String> exchanges;
  final List<ExchangeBreakdown>? exchangeBreakdown;
  final double? avgBuyPriceUsdt;

  const AssetBalance({
    required this.asset,
    required this.free,
    required this.locked,
    required this.total,
    this.priceUsd,
    this.valueUsd,
    this.change24h,
    this.exchanges = const [],
    this.exchangeBreakdown,
    this.avgBuyPriceUsdt,
  });

  factory AssetBalance.fromJson(Map<String, dynamic> json) {
    return AssetBalance(
      asset: json['asset'] as String,
      free: (json['free'] as num?)?.toDouble() ?? 0,
      locked: (json['locked'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      priceUsd: (json['priceUsd'] as num?)?.toDouble(),
      valueUsd: (json['valueUsd'] as num?)?.toDouble(),
      change24h: (json['change24h'] as num?)?.toDouble(),
      exchanges: (json['exchanges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      exchangeBreakdown: (json['exchangeBreakdown'] as List<dynamic>?)
          ?.map((e) => ExchangeBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      avgBuyPriceUsdt: (json['avgBuyPriceUsdt'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        asset,
        free,
        locked,
        total,
        priceUsd,
        valueUsd,
        change24h,
        exchanges,
        avgBuyPriceUsdt,
      ];
}

class ExchangeBreakdown extends Equatable {
  final String exchange;
  final double total;

  const ExchangeBreakdown({
    required this.exchange,
    required this.total,
  });

  factory ExchangeBreakdown.fromJson(Map<String, dynamic> json) {
    return ExchangeBreakdown(
      exchange: json['exchange'] as String,
      total: (json['total'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [exchange, total];
}

class ExchangeBalance extends Equatable {
  final String exchange;
  final String label;
  final String credentialId;
  final List<AssetBalance> balances;
  final double totalValueUsd;

  const ExchangeBalance({
    required this.exchange,
    required this.label,
    required this.credentialId,
    required this.balances,
    required this.totalValueUsd,
  });

  factory ExchangeBalance.fromJson(Map<String, dynamic> json) {
    return ExchangeBalance(
      exchange: json['exchange'] as String,
      label: json['label'] as String? ?? json['exchange'] as String,
      credentialId: json['credentialId'] as String? ?? '',
      balances: (json['balances'] as List<dynamic>?)
              ?.map((e) => AssetBalance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalValueUsd: (json['totalValueUsd'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [exchange, label, credentialId, balances, totalValueUsd];
}

class ConsolidatedBalance extends Equatable {
  final List<AssetBalance> byAsset;
  final List<ExchangeBalance> byExchange;
  final double totalValueUsd;
  final DateTime? lastUpdated;
  final bool? isCached;
  final bool? isSyncing;
  final double? change24h;
  final double? changeUsd24h;

  const ConsolidatedBalance({
    required this.byAsset,
    required this.byExchange,
    required this.totalValueUsd,
    this.lastUpdated,
    this.isCached,
    this.isSyncing,
    this.change24h,
    this.changeUsd24h,
  });

  factory ConsolidatedBalance.fromJson(Map<String, dynamic> json) {
    return ConsolidatedBalance(
      byAsset: (json['byAsset'] as List<dynamic>?)
              ?.map((e) => AssetBalance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      byExchange: (json['byExchange'] as List<dynamic>?)
              ?.map((e) => ExchangeBalance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalValueUsd: (json['totalValueUsd'] as num?)?.toDouble() ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
      isCached: json['isCached'] as bool?,
      isSyncing: json['isSyncing'] as bool?,
      change24h: (json['change24h'] as num?)?.toDouble(),
      changeUsd24h: (json['changeUsd24h'] as num?)?.toDouble(),
    );
  }

  int get exchangeCount => byExchange.length;
  int get assetCount => byAsset.length;

  @override
  List<Object?> get props => [
        byAsset,
        byExchange,
        totalValueUsd,
        lastUpdated,
        change24h,
        changeUsd24h,
      ];
}
