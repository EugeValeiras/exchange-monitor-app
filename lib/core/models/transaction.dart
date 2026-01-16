import 'package:equatable/equatable.dart';

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
        return 'Deposito';
      case TransactionType.withdrawal:
        return 'Retiro';
      case TransactionType.trade:
        return 'Trade';
      case TransactionType.interest:
        return 'Interes';
      case TransactionType.fee:
        return 'Comision';
      case TransactionType.transfer:
        return 'Transferencia';
    }
  }

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
  bool get isPositive =>
      type == TransactionType.deposit ||
      type == TransactionType.interest ||
      isBuy;

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
