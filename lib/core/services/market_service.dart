import 'package:flutter/foundation.dart';
import '../models/market.dart';
import 'api_service.dart';

/// Los intervalos que ofrece la pantalla de mercado. El límite de velas va
/// atado: en 15 minutos 200 velas son dos días; en semanas, cuatro años.
enum MarketTimeframe {
  m15('15m', '15m', 192),
  h1('1h', '1H', 168),
  h4('4h', '4H', 180),
  d1('1d', '1D', 180),
  w1('1w', '1S', 156);

  const MarketTimeframe(this.api, this.label, this.limit);

  final String api;
  final String label;
  final int limit;
}

/// Velas de un par, para la pantalla de mercado.
///
/// No guarda estado global: cada pantalla crea el suyo y lo tira al salir. El
/// mercado es de quien lo está mirando.
class MarketService extends ChangeNotifier {
  final ApiService _api;

  MarketService(this._api);

  Ohlc? _ohlc;
  bool _loading = false;
  String? _error;
  OpenOrders? _openOrders;

  Ohlc? get ohlc => _ohlc;

  /// Sólo para tests: sembrar velas sin pasar por la red.
  @visibleForTesting
  set ohlcParaTest(Ohlc value) => _ohlc = value;
  bool get isLoading => _loading;
  String? get error => _error;
  OpenOrders? get openOrders => _openOrders;

  /// Las órdenes de este par, del exchange en vivo.
  List<OpenOrder> ordersFor(String symbol) =>
      (_openOrders?.orders ?? const [])
          .where((o) => o.symbol.toUpperCase() == symbol.toUpperCase())
          .toList();

  /// Aplica una vela que llegó por WebSocket.
  ///
  /// Si es del mismo período que la última, la reemplaza; si arrancó uno
  /// nuevo, se agrega. Sin esta distinción una vela en curso se duplicaría
  /// cada vez que Binance la manda, dos veces por segundo.
  void applyLiveCandle(Candle vela) {
    final actual = _ohlc;
    if (actual == null || actual.candles.isEmpty) return;

    final candles = List<Candle>.from(actual.candles);
    final ultima = candles.last;
    if (vela.time.isBefore(ultima.time)) return; // llegó tarde, ya no sirve

    if (vela.time.isAtSameMomentAs(ultima.time)) {
      candles[candles.length - 1] = vela;
    } else {
      candles.add(vela);
      // La ventana no crece para siempre: entra una, sale la más vieja.
      if (candles.length > 400) candles.removeAt(0);
    }

    _ohlc = Ohlc(
      exchange: actual.exchange,
      symbol: actual.symbol,
      timeframe: actual.timeframe,
      candles: candles,
    );
    notifyListeners();
  }

  Future<void> load({
    required String exchange,
    required String symbol,
    required MarketTimeframe timeframe,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _ohlc = await _api.get<Ohlc>(
        '/market-analysis/ohlc',
        queryParameters: {
          'exchange': exchange,
          'symbol': symbol,
          'timeframe': timeframe.api,
          'limit': timeframe.limit,
        },
        fromJson: (data) => Ohlc.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      // Las velas viejas se quedan: una pantalla en blanco dice menos que un
      // gráfico de hace un minuto con el aviso al lado.
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Las órdenes que tenés puestas en el exchange. Se piden por par: sin
  /// símbolo, Binance cobra un peso de rate limit mucho más alto.
  Future<void> loadOpenOrders({
    required String exchange,
    required String symbol,
  }) async {
    try {
      _openOrders = await _api.get<OpenOrders>(
        '/prices/raw/$exchange/open-orders',
        queryParameters: {'symbol': symbol},
        fromJson: (data) => OpenOrders.fromJson(data as Map<String, dynamic>),
      );
    } catch (_) {
      // Sin credencial del exchange no hay órdenes que mostrar, y no es un
      // error de la pantalla: simplemente no se muestra la sección.
      _openOrders = null;
    }
    notifyListeners();
  }

  /// El libro por REST, para los exchanges que no lo emiten por WebSocket.
  Future<OrderBook?> fetchOrderBook({
    required String exchange,
    required String symbol,
    int depth = 20,
  }) async {
    try {
      return await _api.get<OrderBook>(
        '/prices/raw/$exchange/orderbook',
        queryParameters: {'symbol': symbol, 'depth': depth},
        fromJson: (data) => OrderBook.fromJson(data as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }
}
