import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';
import '../models/market.dart';
import '../models/price.dart';

class PriceService extends ChangeNotifier {
  io.Socket? _socket;
  final Map<String, PriceUpdate> _prices = {};
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _authToken;
  final Set<String> _subscribedSymbols = {};

  // Exchange connection status
  bool _binanceConnected = false;
  bool _krakenConnected = false;

  /// Cuántos pares tiene configurados cada exchange que PUEDE emitir
  /// precios en vivo. Llega en `connection:status`.
  Map<String, int> _configured = const {};

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  Map<String, PriceUpdate> get prices => Map.unmodifiable(_prices);
  List<PriceUpdate> get priceList => _prices.values.toList();
  bool get binanceConnected => _binanceConnected;
  bool get krakenConnected => _krakenConnected;

  /// El último libro recibido por par, mientras alguien lo esté mirando.
  final Map<String, OrderBook> _books = {};
  final Set<String> _bookKeys = {};
  final Set<String> _bookUnsupported = {};

  OrderBook? orderBook(String exchange, String symbol) =>
      _books['${exchange.toLowerCase()}:${symbol.toUpperCase()}'];

  /// El exchange no emite profundidad por WebSocket: hay que pedirla por REST.
  bool orderBookUnsupported(String exchange, String symbol) =>
      _bookUnsupported.contains('${exchange.toLowerCase()}:${symbol.toUpperCase()}');

  /// Sólo Binance y Kraken emiten precios en vivo; Nexo no lo hace nunca.
  static const _streamable = {'binance', 'kraken'};

  /// ¿De este exchange ESPERAMOS precios en vivo? Tiene que poder
  /// emitirlos y tener al menos un par configurado: Kraken sin pares no
  /// tiene nada que enviar, y acusarlo de silencio era confundir.
  bool expectsPrices(String exchange) {
    final id = exchange.toLowerCase();
    if (!_streamable.contains(id)) return false;
    // Los futuros de Binance cuentan para Binance.
    final configured = (_configured[id] ?? 0) +
        (id == 'binance' ? (_configured['binanceFutures'] ?? 0) : 0);
    return configured > 0;
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void connect() {
    if (_isConnected || _isConnecting || _authToken == null) return;

    _isConnecting = true;
    notifyListeners();

    final config = AppConfig.instance;

    // Connect to the /prices namespace (namespace is appended to URL, not set via path)
    _socket = io.io(
      '${config.wsBaseUrl}/prices',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': _authToken})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket!.onConnect((_) {
      if (kDebugMode) {
        print('Price socket connected');
      }
      _isConnected = true;
      _isConnecting = false;
      notifyListeners();

      // Re-subscribe to symbols
      if (_subscribedSymbols.isNotEmpty) {
        subscribe(_subscribedSymbols.toList());
      }
      for (final key in _bookKeys) {
        final parts = key.split(':');
        _socket?.emit('orderbook:subscribe', {
          'exchange': parts[0],
          'symbol': parts[1],
        });
      }
    });

    _socket!.onDisconnect((_) {
      if (kDebugMode) {
        print('Price socket disconnected');
      }
      _isConnected = false;
      notifyListeners();
    });

    _socket!.onConnectError((error) {
      if (kDebugMode) {
        print('Price socket connection error: $error');
      }
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
    });

    _socket!.on('prices:initial', (data) {
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final price = PriceUpdate.fromJson(item);
            _prices[price.symbol] = price;
          }
        }
        notifyListeners();
      }
    });

    _socket!.on('price:update', (data) {
      if (data is Map<String, dynamic>) {
        final price = PriceUpdate.fromJson(data);
        _prices[price.symbol] = price;
        notifyListeners();
      }
    });

    _socket!.on('price:tick', (data) {
      if (data is Map<String, dynamic>) {
        final symbol = data['symbol'] as String?;
        final price = (data['price'] as num?)?.toDouble();
        if (symbol != null && price != null) {
          final existing = _prices[symbol];
          if (existing != null) {
            _prices[symbol] = PriceUpdate(
              symbol: symbol,
              price: price,
              change24h: existing.change24h,
              high24h: existing.high24h,
              low24h: existing.low24h,
              source: existing.source,
              timestamp: DateTime.now(),
              prices: existing.prices,
            );
            notifyListeners();
          }
        }
      }
    });

    _socket!.on('orderbook:update', (data) {
      if (data is Map<String, dynamic>) {
        final book = OrderBook.fromJson(data);
        final ex = (data['exchange'] as String? ?? '').toLowerCase();
        _books['$ex:${book.symbol.toUpperCase()}'] = book;
        notifyListeners();
      }
    });

    _socket!.on('orderbook:unsupported', (data) {
      if (data is Map<String, dynamic>) {
        final ex = (data['exchange'] as String? ?? '').toLowerCase();
        final sym = (data['symbol'] as String? ?? '').toUpperCase();
        _bookUnsupported.add('$ex:$sym');
        notifyListeners();
      }
    });

    _socket!.on('connection:status', (data) {
      if (data is Map<String, dynamic>) {
        _binanceConnected = data['binance'] == true;
        _krakenConnected = data['kraken'] == true;
        final configured = data['configured'];
        if (configured is Map) {
          _configured = {
            for (final e in configured.entries)
              e.key.toString(): (e.value as num?)?.toInt() ?? 0,
          };
        }
        notifyListeners();
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    _subscribedSymbols.clear();
    _bookKeys.clear();
    _books.clear();
    notifyListeners();
  }

  void subscribe(List<String> symbols) {
    _subscribedSymbols.addAll(symbols);
    if (_isConnected) {
      _socket?.emit('subscribe', symbols);
    }
  }

  void unsubscribe(List<String> symbols) {
    _subscribedSymbols.removeAll(symbols);
    if (_isConnected) {
      _socket?.emit('unsubscribe', symbols);
    }
  }

  /// Pide el libro de un par. El servidor manda hasta cuatro veces por
  /// segundo mientras haya alguien mirando, así que hay que soltarlo al salir.
  void subscribeOrderBook(String exchange, String symbol) {
    final key = '${exchange.toLowerCase()}:${symbol.toUpperCase()}';
    if (!_bookKeys.add(key)) return;
    if (_isConnected) {
      _socket?.emit('orderbook:subscribe', {
        'exchange': exchange.toLowerCase(),
        'symbol': symbol.toUpperCase(),
      });
    } else {
      connect();
    }
  }

  void unsubscribeOrderBook(String exchange, String symbol) {
    final key = '${exchange.toLowerCase()}:${symbol.toUpperCase()}';
    if (!_bookKeys.remove(key)) return;
    _books.remove(key);
    if (_isConnected) {
      _socket?.emit('orderbook:unsubscribe', {
        'exchange': exchange.toLowerCase(),
        'symbol': symbol.toUpperCase(),
      });
    }
  }

  PriceUpdate? getPrice(String symbol) {
    return _prices[symbol];
  }

  double? getPriceByAsset(String asset) {
    // Try common pairs
    final pairs = [
      '$asset/USDT',
      '$asset/USD',
      '$asset/BUSD',
    ];

    for (final pair in pairs) {
      final price = _prices[pair];
      if (price != null) {
        return price.price;
      }
    }

    // Check all prices for matching asset
    for (final price in _prices.values) {
      if (price.asset == asset) {
        return price.price;
      }
    }

    return null;
  }

  double? getChange24hByAsset(String asset) {
    final pairs = ['$asset/USDT', '$asset/USD'];
    for (final pair in pairs) {
      final price = _prices[pair];
      if (price != null) {
        return price.change24h;
      }
    }
    return null;
  }

  List<PriceUpdate> getFilteredPrices({
    String? exchange,
    String? asset,
    String? quote,
  }) {
    return priceList.where((p) {
      if (exchange != null && p.source != exchange) return false;
      if (asset != null && p.asset != asset) return false;
      if (quote != null && p.quote != quote) return false;
      return true;
    }).toList();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
