import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import 'api_service.dart';

class TransactionService extends ChangeNotifier {
  final ApiService _apiService;

  List<Transaction> _transactions = [];
  TransactionStats? _stats;
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
