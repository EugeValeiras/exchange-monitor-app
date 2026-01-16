import 'package:equatable/equatable.dart';

class PriceUpdate extends Equatable {
  final String symbol;
  final double price;
  final double? change24h;
  final double? high24h;
  final double? low24h;
  final String? source;
  final DateTime? timestamp;
  final List<ExchangePrice>? prices;

  const PriceUpdate({
    required this.symbol,
    required this.price,
    this.change24h,
    this.high24h,
    this.low24h,
    this.source,
    this.timestamp,
    this.prices,
  });

  String get asset {
    final parts = symbol.split('/');
    return parts.isNotEmpty ? parts[0] : symbol;
  }

  String get quote {
    final parts = symbol.split('/');
    return parts.length > 1 ? parts[1] : 'USD';
  }

  factory PriceUpdate.fromJson(Map<String, dynamic> json) {
    return PriceUpdate(
      symbol: json['symbol'] as String,
      price: (json['price'] as num).toDouble(),
      change24h: (json['change24h'] as num?)?.toDouble(),
      high24h: (json['high24h'] as num?)?.toDouble(),
      low24h: (json['low24h'] as num?)?.toDouble(),
      source: json['source'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
      prices: (json['prices'] as List<dynamic>?)
          ?.map((e) => ExchangePrice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [symbol, price, change24h, source, timestamp];
}

class ExchangePrice extends Equatable {
  final String exchange;
  final double price;
  final double? change24h;
  final String? pair;

  const ExchangePrice({
    required this.exchange,
    required this.price,
    this.change24h,
    this.pair,
  });

  factory ExchangePrice.fromJson(Map<String, dynamic> json) {
    return ExchangePrice(
      exchange: json['exchange'] as String,
      price: (json['price'] as num).toDouble(),
      change24h: (json['change24h'] as num?)?.toDouble(),
      pair: json['pair'] as String?,
    );
  }

  @override
  List<Object?> get props => [exchange, price, change24h, pair];
}

class MultiExchangePriceResult extends Equatable {
  final double averagePrice;
  final List<ExchangePrice> prices;
  final String pair;
  final double? change24h;

  const MultiExchangePriceResult({
    required this.averagePrice,
    required this.prices,
    required this.pair,
    this.change24h,
  });

  factory MultiExchangePriceResult.fromJson(Map<String, dynamic> json) {
    return MultiExchangePriceResult(
      averagePrice: (json['averagePrice'] as num).toDouble(),
      prices: (json['prices'] as List<dynamic>)
          .map((e) => ExchangePrice.fromJson(e as Map<String, dynamic>))
          .toList(),
      pair: json['pair'] as String,
      change24h: (json['change24h'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [averagePrice, prices, pair, change24h];
}
