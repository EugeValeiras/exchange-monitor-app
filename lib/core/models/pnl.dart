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

/// Un lote de compra abierto, de `GET /pnl/lots`.
///
/// Es la unidad de la que está hecho el no realizado: cada compra que todavía
/// tenés, con lo que pagaste por ella. La contabilidad es FIFO, así que una
/// venta consume los lotes más viejos primero y lo que queda acá es lo que
/// sobrevivió.
class CostBasisLot extends Equatable {
  final String id;
  final String asset;
  final String exchange;

  /// Cómo entró: una compra, un depósito, un swap desde otro par.
  final String source;
  final DateTime acquiredAt;
  final double originalAmount;

  /// Lo que queda del lote después de las ventas que lo consumieron.
  final double remainingAmount;
  final double costPerUnit;
  final double totalCost;

  /// El par por el que entró, cuando no fue contra USD (NEXO/BTC, por ejemplo).
  final String? pair;

  const CostBasisLot({
    required this.id,
    required this.asset,
    required this.exchange,
    required this.source,
    required this.acquiredAt,
    required this.originalAmount,
    required this.remainingAmount,
    required this.costPerUnit,
    required this.totalCost,
    this.pair,
  });

  /// Lo que este lote aporta al no realizado, al precio de ahora.
  double unrealizedAt(double price) => (price - costPerUnit) * remainingAmount;

  /// Lo que costó la parte que todavía tenés — no [totalCost], que es lo que
  /// costó el lote entero antes de que las ventas se comieran una parte.
  double get remainingCost => costPerUnit * remainingAmount;

  /// El lote fue consumido en parte por una venta.
  bool get isPartial => remainingAmount < originalAmount;

  factory CostBasisLot.fromJson(Map<String, dynamic> json) {
    return CostBasisLot(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      asset: json['asset'] as String,
      exchange: (json['exchange'] as String?) ?? '',
      source: (json['source'] as String?) ?? '',
      acquiredAt:
          DateTime.tryParse(json['acquiredAt']?.toString() ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      originalAmount: (json['originalAmount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0,
      costPerUnit: (json['costPerUnit'] as num?)?.toDouble() ?? 0,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
      pair: json['pair'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, asset, exchange, acquiredAt, remainingAmount];
}

/// Una venta ya cerrada, de `GET /pnl/realized`.
///
/// Es la unidad de la que está hecho el realizado: la API guarda un documento
/// por venta con los lotes que consumió, así que la suma de estas filas es
/// exactamente el número del card.
class RealizedPnlItem extends Equatable {
  final String id;
  final String asset;
  final double amount;

  /// Lo que entró por la venta.
  final double proceeds;

  /// Lo que habían costado los lotes que la venta consumió.
  final double costBasis;
  final double realizedPnl;
  final DateTime realizedAt;
  final String exchange;
  final double buyPrice;
  final double sellPrice;

  const RealizedPnlItem({
    required this.id,
    required this.asset,
    required this.amount,
    required this.proceeds,
    required this.costBasis,
    required this.realizedPnl,
    required this.realizedAt,
    required this.exchange,
    required this.buyPrice,
    required this.sellPrice,
  });

  /// Cuánto rindió respecto de lo que había costado.
  double? get percent =>
      costBasis > 0 ? (realizedPnl / costBasis) * 100 : null;

  factory RealizedPnlItem.fromJson(Map<String, dynamic> json) {
    return RealizedPnlItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      asset: json['asset'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      proceeds: (json['proceeds'] as num?)?.toDouble() ?? 0,
      costBasis: (json['costBasis'] as num?)?.toDouble() ?? 0,
      realizedPnl: (json['realizedPnl'] as num?)?.toDouble() ?? 0,
      realizedAt:
          DateTime.tryParse(json['realizedAt']?.toString() ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      exchange: (json['exchange'] as String?) ?? '',
      buyPrice: (json['buyPrice'] as num?)?.toDouble() ?? 0,
      sellPrice: (json['sellPrice'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, asset, realizedAt, realizedPnl];
}
