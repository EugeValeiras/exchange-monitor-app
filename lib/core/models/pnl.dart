import 'package:equatable/equatable.dart';

/// Resultado por activo, tal como lo devuelve `GET /pnl/summary`.
class AssetPnl extends Equatable {
  final String asset;
  final double realizedPnl;
  final double unrealizedPnl;
  final double totalCostBasis;
  final double currentValue;

  /// Cantidad SEGÚN LA CONTABILIDAD DE LOTES, que no siempre coincide con el
  /// saldo real del exchange (ver [PnlPosition.matchesBalance]).
  final double totalAmount;

  const AssetPnl({
    required this.asset,
    required this.realizedPnl,
    required this.unrealizedPnl,
    required this.totalCostBasis,
    required this.currentValue,
    required this.totalAmount,
  });

  double get totalPnl => realizedPnl + unrealizedPnl;

  /// Precio promedio de compra. Sin cantidad no hay PPC posible.
  double? get avgBuyPrice =>
      totalAmount > 0 ? totalCostBasis / totalAmount : null;

  factory AssetPnl.fromJson(Map<String, dynamic> json) {
    return AssetPnl(
      asset: json['asset'] as String,
      realizedPnl: (json['realizedPnl'] as num?)?.toDouble() ?? 0,
      unrealizedPnl: (json['unrealizedPnl'] as num?)?.toDouble() ?? 0,
      totalCostBasis: (json['totalCostBasis'] as num?)?.toDouble() ?? 0,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [asset, realizedPnl, unrealizedPnl, totalCostBasis, currentValue, totalAmount];
}

/// Posición abierta, de `GET /pnl/unrealized`.
class PnlPosition extends Equatable {
  final String asset;
  final double amount;
  final double costBasis;
  final double currentValue;
  final double unrealizedPnl;
  final double unrealizedPnlPercent;

  const PnlPosition({
    required this.asset,
    required this.amount,
    required this.costBasis,
    required this.currentValue,
    required this.unrealizedPnl,
    required this.unrealizedPnlPercent,
  });

  double? get avgBuyPrice => amount > 0 ? costBasis / amount : null;

  /// La contabilidad de lotes puede haber quedado desfasada del saldo real
  /// (importaciones incompletas, transferencias sin registrar). Cuando pasa,
  /// el PPC sigue siendo el mejor dato disponible pero la app tiene que
  /// decirlo en vez de presentarlo como verdad.
  bool matchesBalance(double? balanceAmount) {
    if (balanceAmount == null || balanceAmount == 0 || amount == 0) return true;
    final ratio = (amount - balanceAmount).abs() / balanceAmount.abs();
    return ratio <= 0.01;
  }

  factory PnlPosition.fromJson(Map<String, dynamic> json) {
    return PnlPosition(
      asset: json['asset'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      costBasis: (json['costBasis'] as num?)?.toDouble() ?? 0,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0,
      unrealizedPnl: (json['unrealizedPnl'] as num?)?.toDouble() ?? 0,
      unrealizedPnlPercent: (json['unrealizedPnlPercent'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [asset, amount, costBasis, currentValue, unrealizedPnl, unrealizedPnlPercent];
}

class PnlSummary extends Equatable {
  final double totalRealizedPnl;
  final double totalUnrealizedPnl;
  final double totalPnl;
  final List<AssetPnl> byAsset;

  const PnlSummary({
    required this.totalRealizedPnl,
    required this.totalUnrealizedPnl,
    required this.totalPnl,
    required this.byAsset,
  });

  AssetPnl? forAsset(String asset) {
    final upper = asset.toUpperCase();
    for (final a in byAsset) {
      if (a.asset.toUpperCase() == upper) return a;
    }
    return null;
  }

  factory PnlSummary.fromJson(Map<String, dynamic> json) {
    return PnlSummary(
      totalRealizedPnl: (json['totalRealizedPnl'] as num?)?.toDouble() ?? 0,
      totalUnrealizedPnl: (json['totalUnrealizedPnl'] as num?)?.toDouble() ?? 0,
      totalPnl: (json['totalPnl'] as num?)?.toDouble() ?? 0,
      byAsset: (json['byAsset'] as List<dynamic>?)
              ?.map((e) => AssetPnl.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props =>
      [totalRealizedPnl, totalUnrealizedPnl, totalPnl, byAsset];
}
