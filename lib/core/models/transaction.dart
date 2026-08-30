import 'package:equatable/equatable.dart';

import '../utils/formatters.dart';

/// Hacia dónde se mueve la plata. Es lo que decide el signo y el color de un
/// movimiento: antes el monto se pintaba según `isPositive`, y por eso un
/// retiro salía en verde con un "+" adelante, idéntico a un depósito.
enum TransactionDirection { inflow, outflow, neutral }

enum TransactionType {
  deposit,
  withdrawal,
  trade,
  interest,
  fee,
  transfer,
}

extension TransactionTypeExtension on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.deposit:
        return 'Depósito';
      case TransactionType.withdrawal:
        return 'Retiro';
      case TransactionType.trade:
        return 'Operación';
      case TransactionType.interest:
        return 'Intereses';
      case TransactionType.fee:
        return 'Comisión';
      case TransactionType.transfer:
        return 'Transferencia';
    }
  }

  /// Un depósito y un retiro son CAPITAL, no resultado: por eso no se pintan
  /// de verde ni de rojo, que están reservados para variación de valor.
  bool get isCapitalFlow =>
      this == TransactionType.deposit ||
      this == TransactionType.withdrawal ||
      this == TransactionType.transfer;

  static TransactionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'deposit':
        return TransactionType.deposit;
      case 'withdrawal':
        return TransactionType.withdrawal;
      case 'trade':
        return TransactionType.trade;
      case 'interest':
        return TransactionType.interest;
      case 'fee':
        return TransactionType.fee;
      case 'transfer':
        return TransactionType.transfer;
      default:
        return TransactionType.trade;
    }
  }
}

class Transaction extends Equatable {
  final String id;
  final String exchange;
  final String? externalId;
  final TransactionType type;
  final String asset;
  final double amount;
  final double? fee;
  final String? feeAsset;
  final double? price;
  final String? priceAsset;
  final String? pair;
  final String? side;
  final DateTime timestamp;

  const Transaction({
    required this.id,
    required this.exchange,
    this.externalId,
    required this.type,
    required this.asset,
    required this.amount,
    this.fee,
    this.feeAsset,
    this.price,
    this.priceAsset,
    this.pair,
    this.side,
    required this.timestamp,
  });

  bool get isBuy => side?.toLowerCase() == 'buy';
  bool get isSell => side?.toLowerCase() == 'sell';

  /// Dirección real del movimiento. Para una operación manda el lado; para el
  /// resto, el tipo. Una transferencia se resuelve por el signo del monto.
  TransactionDirection get direction {
    switch (type) {
      case TransactionType.deposit:
      case TransactionType.interest:
        return TransactionDirection.inflow;
      case TransactionType.withdrawal:
      case TransactionType.fee:
        return TransactionDirection.outflow;
      case TransactionType.trade:
        if (isBuy) return TransactionDirection.inflow;
        if (isSell) return TransactionDirection.outflow;
        return amount < 0 ? TransactionDirection.outflow : TransactionDirection.inflow;
      case TransactionType.transfer:
        return amount < 0 ? TransactionDirection.outflow : TransactionDirection.inflow;
    }
  }

  bool get isOutflow => direction == TransactionDirection.outflow;

  /// Monto con el signo que le corresponde a la dirección. La API manda el
  /// monto en valor absoluto para casi todo, así que el signo se deriva acá.
  double get signedAmount => isOutflow ? -amount.abs() : amount.abs();

  /// Valor en dólares del movimiento, cuando se puede saber sin inventarlo:
  /// el activo ya es un dólar, o la transacción trae el precio del momento.
  /// Nunca se valoriza con el precio de hoy — eso mentiría sobre el pasado.
  double? get usdValue {
    if (isDollarQuote(asset)) return amount.abs();
    if (price != null && price! > 0 && (priceAsset == null || isDollarQuote(priceAsset!))) {
      return amount.abs() * price!;
    }
    return null;
  }

  /// Fecha sin hora, para agrupar por día.
  DateTime get day {
    final local = timestamp.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  @Deprecated('Usar direction: isPositive no distinguía un retiro de un depósito')
  bool get isPositive => direction == TransactionDirection.inflow;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      exchange: json['exchange'] as String,
      externalId: json['externalId'] as String?,
      type: TransactionTypeExtension.fromString(json['type'] as String),
      asset: json['asset'] as String,
      amount: (json['amount'] as num).toDouble(),
      fee: (json['fee'] as num?)?.toDouble(),
      feeAsset: json['feeAsset'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      priceAsset: json['priceAsset'] as String?,
      pair: json['pair'] as String?,
      side: json['side'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        exchange,
        type,
        asset,
        amount,
        fee,
        price,
        pair,
        side,
        timestamp,
      ];
}

class PaginatedTransactions {
  final List<Transaction> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const PaginatedTransactions({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory PaginatedTransactions.fromJson(Map<String, dynamic> json) {
    return PaginatedTransactions(
      data: (json['data'] as List<dynamic>)
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}

class TransactionStats {
  final int totalTransactions;
  final Map<String, int> byType;
  final Map<String, int> byExchange;
  final Map<String, int> byAsset;
  final double? totalInterestUsd;
  final double? totalFeesUsd;

  const TransactionStats({
    required this.totalTransactions,
    required this.byType,
    required this.byExchange,
    required this.byAsset,
    this.totalInterestUsd,
    this.totalFeesUsd,
  });

  int get totalCount => totalTransactions;

  factory TransactionStats.fromJson(Map<String, dynamic> json) {
    return TransactionStats(
      totalTransactions: json['totalTransactions'] as int,
      byType: Map<String, int>.from(json['byType'] as Map? ?? {}),
      byExchange: Map<String, int>.from(json['byExchange'] as Map? ?? {}),
      byAsset: Map<String, int>.from(json['byAsset'] as Map? ?? {}),
      totalInterestUsd: (json['totalInterestUsd'] as num?)?.toDouble(),
      totalFeesUsd: (json['totalFeesUsd'] as num?)?.toDouble(),
    );
  }
}

class TransactionFilter {
  final int? page;
  final int? limit;
  final String? exchange;
  final List<String>? exchanges;
  final TransactionType? type;
  final List<TransactionType>? types;
  final String? asset;
  final List<String>? assets;
  final DateTime? startDate;
  final DateTime? endDate;

  const TransactionFilter({
    this.page,
    this.limit,
    this.exchange,
    this.exchanges,
    this.type,
    this.types,
    this.asset,
    this.assets,
    this.startDate,
    this.endDate,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (page != null) params['page'] = page.toString();
    if (limit != null) params['limit'] = limit.toString();
    if (exchange != null) params['exchange'] = exchange!;
    if (exchanges != null && exchanges!.isNotEmpty) {
      params['exchanges'] = exchanges!.join(',');
    }
    if (type != null) params['type'] = type!.name;
    if (types != null && types!.isNotEmpty) {
      params['types'] = types!.map((t) => t.name).join(',');
    }
    if (asset != null) params['asset'] = asset!;
    if (assets != null && assets!.isNotEmpty) {
      params['assets'] = assets!.join(',');
    }
    if (startDate != null) params['startDate'] = startDate!.toIso8601String();
    if (endDate != null) params['endDate'] = endDate!.toIso8601String();
    return params;
  }
}
