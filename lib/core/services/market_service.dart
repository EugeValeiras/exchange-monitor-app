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

  Ohlc? get ohlc => _ohlc;
  bool get isLoading => _loading;
  String? get error => _error;

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
