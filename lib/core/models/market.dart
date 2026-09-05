/// Una vela: el rango de precio de un período.
class Candle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  bool get isUp => close >= open;

  factory Candle.fromJson(Map<String, dynamic> json) => Candle(
        time: DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt()),
        open: (json['open'] as num).toDouble(),
        high: (json['high'] as num).toDouble(),
        low: (json['low'] as num).toDouble(),
        close: (json['close'] as num).toDouble(),
        volume: (json['volume'] as num?)?.toDouble() ?? 0,
      );
}

class Ohlc {
  final String exchange;
  final String symbol;
  final String timeframe;
  final List<Candle> candles;

  const Ohlc({
    required this.exchange,
    required this.symbol,
    required this.timeframe,
    required this.candles,
  });

  factory Ohlc.fromJson(Map<String, dynamic> json) => Ohlc(
        exchange: json['exchange'] as String? ?? '',
        symbol: json['symbol'] as String? ?? '',
        timeframe: json['timeframe'] as String? ?? '',
        candles: ((json['candles'] as List<dynamic>?) ?? const [])
            .map((c) => Candle.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  /// Máximo, mínimo y volumen del tramo visible. Son los datos que la cabecera
  /// muestra al lado del precio, y salen de las velas: no hay que pedirlos.
  double? get high => candles.isEmpty
      ? null
      : candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
  double? get low => candles.isEmpty
      ? null
      : candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
  double get volume => candles.fold(0.0, (s, c) => s + c.volume);
}

/// Un nivel del libro: a qué precio y por cuánto.
class BookLevel {
  final double price;
  final double amount;

  const BookLevel(this.price, this.amount);
}

/// El libro de órdenes de un par en un instante.
class OrderBook {
  final String symbol;
  final DateTime at;
  final List<BookLevel> bids;
  final List<BookLevel> asks;

  const OrderBook({
    required this.symbol,
    required this.at,
    required this.bids,
    required this.asks,
  });

  /// Los precios pueden venir como número o como texto: la API los manda
  /// numéricos, pero Binance los emite en string y una capa de más en el medio
  /// no debería tirar el libro entero.
  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  static List<BookLevel> _levels(dynamic raw) =>
      ((raw as List<dynamic>?) ?? const [])
          .whereType<List<dynamic>>()
          .where((l) => l.length >= 2)
          .map((l) => BookLevel(_num(l[0]), _num(l[1])))
          .where((l) => l.amount > 0 && l.price > 0)
          .toList();

  factory OrderBook.fromJson(Map<String, dynamic> json) => OrderBook(
        symbol: json['symbol'] as String? ?? '',
        at: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
        bids: _levels(json['bids']),
        asks: _levels(json['asks']),
      );

  double? get bestBid => bids.isEmpty ? null : bids.first.price;
  double? get bestAsk => asks.isEmpty ? null : asks.first.price;

  /// La distancia entre la mejor compra y la mejor venta: lo que te cuesta
  /// entrar y salir en el acto.
  double? get spread {
    final b = bestBid, a = bestAsk;
    return (b == null || a == null) ? null : a - b;
  }

  double? get spreadPct {
    final s = spread, a = bestAsk;
    return (s == null || a == null || a == 0) ? null : s / a * 100;
  }
}

/// Una orden puesta en el exchange que todavía no se ejecutó.
class OpenOrder {
  final String id;
  final String symbol;
  final bool isBuy;
  final String type;

  /// Precio de la orden. Null en las de mercado.
  final double? price;

  /// Precio al que se dispara una condicional. Es el que la ubica en el
  /// gráfico cuando la orden todavía no tiene precio propio.
  final double? triggerPrice;

  final double amount;
  final double filled;
  final double remaining;
  final DateTime? createdAt;

  const OpenOrder({
    required this.id,
    required this.symbol,
    required this.isBuy,
    required this.type,
    required this.amount,
    required this.filled,
    required this.remaining,
    this.price,
    this.triggerPrice,
    this.createdAt,
  });

  /// Dónde se dibuja: el precio propio, y si no lo tiene, el de disparo.
  double? get chartPrice => price ?? triggerPrice;

  /// Cuánto se ejecutó ya, de 0 a 1.
  double get progress => amount > 0 ? (filled / amount).clamp(0.0, 1.0) : 0;

  factory OpenOrder.fromJson(Map<String, dynamic> json) => OpenOrder(
        id: json['id']?.toString() ?? '',
        symbol: json['symbol'] as String? ?? '',
        isBuy: (json['side'] as String? ?? 'buy') != 'sell',
        type: json['type'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble(),
        triggerPrice: (json['triggerPrice'] as num?)?.toDouble(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        filled: (json['filled'] as num?)?.toDouble() ?? 0,
        remaining: (json['remaining'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

class OpenOrders {
  final String exchange;
  final bool supported;
  final List<OpenOrder> orders;

  const OpenOrders({
    required this.exchange,
    required this.supported,
    required this.orders,
  });

  factory OpenOrders.fromJson(Map<String, dynamic> json) => OpenOrders(
        exchange: json['exchange'] as String? ?? '',
        supported: json['supported'] as bool? ?? false,
        orders: ((json['orders'] as List<dynamic>?) ?? const [])
            .map((o) => OpenOrder.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}

