import 'package:flutter/foundation.dart';

import '../models/pnl.dart';
import 'api_service.dart';

/// Resultado de la cartera: realizado, no realizado y precio promedio de
/// compra por activo.
///
/// La API lo calcula desde siempre (módulo `pnl`) y la app nunca lo pidió: era
/// el único cliente del sistema que no mostraba cuánto se ganó o se perdió.
class PnlService extends ChangeNotifier {
  final ApiService _apiService;

  PnlSummary? _summary;
  List<PnlPosition> _positions = const [];
  bool _isLoading = false;
  String? _error;

  PnlService(this._apiService);

  PnlSummary? get summary => _summary;
  List<PnlPosition> get positions => _positions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _summary != null;

  double get totalPnl => _summary?.totalPnl ?? 0;
  double get realizedPnl => _summary?.totalRealizedPnl ?? 0;
  double get unrealizedPnl => _summary?.totalUnrealizedPnl ?? 0;

  PnlPosition? positionFor(String asset) {
    final upper = asset.toUpperCase();
    for (final p in _positions) {
      if (p.asset.toUpperCase() == upper) return p;
    }
    return null;
  }

  AssetPnl? pnlFor(String asset) => _summary?.forAsset(asset);

  /// Precio promedio de compra del activo, o null si la contabilidad no tiene
  /// lotes suficientes para calcularlo.
  double? avgBuyPrice(String asset) =>
      positionFor(asset)?.avgBuyPrice ?? pnlFor(asset)?.avgBuyPrice;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.get<Map<String, dynamic>>('/pnl/summary'),
        _apiService.get<Map<String, dynamic>>('/pnl/unrealized'),
      ]);

      _summary = PnlSummary.fromJson(results[0]);
      _positions = (results[1]['positions'] as List<dynamic>?)
              ?.map((e) => PnlPosition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [];
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
      if (kDebugMode) print('Error cargando P&L: $e');
    } catch (e) {
      _error = 'No se pudo cargar el resultado';
      if (kDebugMode) print('Error cargando P&L: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
