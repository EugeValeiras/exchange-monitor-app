import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import 'api_service.dart';

/// Una entrada de la lista: o un movimiento suelto, o varios idénticos del
/// mismo día plegados en uno.
class MovementEntry {
  final List<Transaction> items;

  const MovementEntry(this.items);

  bool get isGroup => items.length > 1;
  Transaction get first => items.first;
}

/// Los movimientos de un día.
class DaySection {
  final DateTime day;
  final List<MovementEntry> entries;
  final int movementCount;

  const DaySection({
    required this.day,
    required this.entries,
    required this.movementCount,
  });
}

class TransactionService extends ChangeNotifier {
  final ApiService _apiService;

  List<Transaction> _transactions = [];
  TransactionStats? _stats;

  /// Totales de SIEMPRE, sin ningún filtro aplicado.
  ///
  /// `_stats` sigue al filtro que tenga puesto la pantalla de Movimientos, y
  /// Posición comparte este mismo servicio: con "Este mes" seleccionado y el
  /// mes recién empezado, el card de intereses mostraba "+$0" debajo de un
  /// encabezado que dice "desde el inicio".
  TransactionStats? _lifetimeStats;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;
  TransactionFilter _currentFilter = const TransactionFilter(limit: 20);

  // Available exchanges - loaded once and never re-filtered
  List<String>? _availableExchanges;

  TransactionService(this._apiService);

  List<Transaction> get transactions => _transactions;
  TransactionStats? get stats => _stats;
  TransactionStats? get lifetimeStats => _lifetimeStats;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get total => _total;
  bool get hasMore => _currentPage < _totalPages;
  TransactionFilter get currentFilter => _currentFilter;

  // Filter state getters for UI
  List<TransactionType> get selectedTypes => _currentFilter.types ?? [];
  List<String> get selectedExchanges => _currentFilter.exchanges ?? [];
  List<String> get availableExchanges => _availableExchanges ?? [];
  DateTime? get startDate => _currentFilter.startDate;
  DateTime? get endDate => _currentFilter.endDate;

  /// La lista agrupada por día, con los repetidos plegados.
  ///
  /// Antes eran 1.883 tarjetas en un chorro plano, y como Nexo acredita
  /// intereses una docena de veces por día con el mismo importe y la misma
  /// hora, tres días de intereses tapaban todo lo demás.
  List<DaySection> get sections {
    if (_transactions.isEmpty) return const [];

    final byDay = <DateTime, List<Transaction>>{};
    for (final t in _transactions) {
      byDay.putIfAbsent(t.day, () => []).add(t);
    }

    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final day in days)
        DaySection(
          day: day,
          entries: _groupSameKind(byDay[day]!),
          movementCount: byDay[day]!.length,
        ),
    ];
  }

  /// Pliega los movimientos de un día que son uno solo.
  ///
  /// Dos casos distintos. Los intereses y comisiones se pliegan por REPETICIÓN
  /// —hacen falta tres o más, si no tapan todo lo demás— y un depósito o una
  /// operación no se pliegan nunca: son eventos con identidad propia.
  ///
  /// Un traspaso entre tus exchanges es otra cosa: sus dos puntas son el mismo
  /// hecho contado dos veces, así que se juntan siempre, sin umbral. La API
  /// dice cuáles van juntas con `transferGroupId`.
  List<MovementEntry> _groupSameKind(List<Transaction> dayItems) {
    const groupable = {TransactionType.interest, TransactionType.fee};
    const threshold = 3;

    final buckets = <String, List<Transaction>>{};
    final order = <String>[];

    for (final t in dayItems) {
      final traspaso = t.transferGroupId;
      final key = traspaso != null
          ? 'transfer|$traspaso'
          : groupable.contains(t.type)
              ? '${t.type.name}|${t.asset}|${t.exchange}'
              : 'single|${t.id}';
      if (!buckets.containsKey(key)) order.add(key);
      buckets.putIfAbsent(key, () => []).add(t);
    }

    final entries = <MovementEntry>[];
    for (final key in order) {
      final items = buckets[key]!;
      // Un traspaso se junta con sus dos puntas; el resto necesita repetirse.
      final minimo = key.startsWith('transfer|') ? 2 : threshold;
      if (items.length >= minimo) {
        entries.add(MovementEntry(items));
      } else {
        for (final t in items) {
          entries.add(MovementEntry([t]));
        }
      }
    }

    entries.sort((a, b) => b.first.timestamp.compareTo(a.first.timestamp));
    return entries;
  }

  Future<void> loadTransactions({TransactionFilter? filter, bool refresh = false}) async {
    if (filter != null) {
      _currentFilter = filter;
    }

    if (refresh) {
      _currentPage = 1;
      _transactions = [];
    }

    _isLoading = _transactions.isEmpty;
    _error = null;
    notifyListeners();

    try {
      final queryParams = {
        ..._currentFilter.toQueryParams(),
        'page': _currentPage.toString(),
      };

      final response = await _apiService.get<Map<String, dynamic>>(
        '/transactions',
        queryParameters: queryParams,
      );

      final paginated = PaginatedTransactions.fromJson(response);

      if (refresh || _currentPage == 1) {
        _transactions = paginated.data;
      } else {
        _transactions.addAll(paginated.data);
      }

      _total = paginated.total;
      _totalPages = paginated.totalPages;
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
      if (kDebugMode) {
        print('Error loading transactions: $e');
      }
    } catch (e) {
      _error = 'Failed to load transactions';
      if (kDebugMode) {
        print('Error loading transactions: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

    _currentPage++;

    try {
      final queryParams = {
        ..._currentFilter.toQueryParams(),
        'page': _currentPage.toString(),
      };

      final response = await _apiService.get<Map<String, dynamic>>(
        '/transactions',
        queryParameters: queryParams,
      );

      final paginated = PaginatedTransactions.fromJson(response);
      _transactions.addAll(paginated.data);
    } on ApiException catch (e) {
      _currentPage--; // Revert page on error
      _error = e.message;
    } catch (e) {
      _currentPage--;
      _error = 'Failed to load more transactions';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Los totales sin filtro. Se piden aparte y no los toca ninguna pantalla.
  Future<void> loadLifetimeStats() async {
    try {
      final response =
          await _apiService.get<Map<String, dynamic>>('/transactions/stats');
      _lifetimeStats = TransactionStats.fromJson(response);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error cargando totales de siempre: $e');
    }
  }

  Future<void> loadStats() async {
    try {
      final queryParams = <String, dynamic>{};
      if (_currentFilter.startDate != null) {
        queryParams['startDate'] = _currentFilter.startDate!.toIso8601String();
      }
      if (_currentFilter.endDate != null) {
        queryParams['endDate'] = _currentFilter.endDate!.toIso8601String();
      }
      if (_currentFilter.exchange != null) {
        queryParams['exchange'] = _currentFilter.exchange!;
      }
      if (_currentFilter.types != null && _currentFilter.types!.isNotEmpty) {
        queryParams['types'] = _currentFilter.types!.map((t) => t.name).join(',');
      }
      if (_currentFilter.assets != null && _currentFilter.assets!.isNotEmpty) {
        queryParams['assets'] = _currentFilter.assets!.join(',');
      }

      final response = await _apiService.get<Map<String, dynamic>>(
        '/transactions/stats',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      _stats = TransactionStats.fromJson(response);

      // Store available exchanges only once (first load without filters)
      if (_availableExchanges == null && _stats != null) {
        _availableExchanges = _stats!.byExchange.keys.toList();
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading stats: $e');
      }
    }
  }

  Future<void> refresh() async {
    await Future.wait([
      loadTransactions(refresh: true),
      loadStats(),
    ]);
  }

  void setFilter(TransactionFilter filter) {
    _currentFilter = filter;
    loadTransactions(refresh: true);
    loadStats();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _currentFilter = TransactionFilter(
      page: 1,
      limit: _currentFilter.limit,
      exchange: _currentFilter.exchange,
      types: _currentFilter.types,
      assets: _currentFilter.assets,
      startDate: start,
      endDate: end,
    );
    refresh();
  }

  void setExchangeFilter(List<String> exchanges) {
    // API only supports single exchange filter
    // When multiple selected, don't filter by exchange (show all)
    _currentFilter = TransactionFilter(
      page: 1,
      limit: _currentFilter.limit,
      exchange: exchanges.length == 1 ? exchanges.first : null,
      exchanges: exchanges.isEmpty ? null : exchanges, // Keep for UI state
      types: _currentFilter.types,
      assets: _currentFilter.assets,
      startDate: _currentFilter.startDate,
      endDate: _currentFilter.endDate,
    );
    loadTransactions(refresh: true);
    loadStats();
  }

  void setTypeFilter(List<TransactionType> types) {
    _currentFilter = TransactionFilter(
      page: 1,
      limit: _currentFilter.limit,
      exchange: _currentFilter.exchange,
      exchanges: _currentFilter.exchanges,
      types: types.isEmpty ? null : types,
      assets: _currentFilter.assets,
      startDate: _currentFilter.startDate,
      endDate: _currentFilter.endDate,
    );
    loadTransactions(refresh: true);
    loadStats();
  }

  void setAssetFilters(List<String>? assets) {
    _currentFilter = TransactionFilter(
      page: 1,
      limit: _currentFilter.limit,
      exchange: _currentFilter.exchange,
      exchanges: _currentFilter.exchanges,
      types: _currentFilter.types,
      assets: assets,
      startDate: _currentFilter.startDate,
      endDate: _currentFilter.endDate,
    );
    loadTransactions(refresh: true);
    loadStats();
  }

  void clearFilters() {
    _currentFilter = const TransactionFilter(limit: 20);
    refresh();
  }
}
