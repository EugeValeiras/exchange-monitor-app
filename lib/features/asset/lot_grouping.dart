import '../../core/models/pnl.dart';

/// Operaciones más cercanas que esto son candidatas a ser fills de la misma
/// orden. Es la misma ventana que usa la webapp para colapsar fills, así que
/// un movimiento se agrupa igual en los dos clientes.
const Duration kFillWindow = Duration(minutes: 15);

/// Un lote, o los fills de una misma compra vistos como uno solo.
///
/// Una orden de 0,0042 BTC ejecutada en 47 pedacitos entra a la contabilidad
/// como 47 lotes idénticos. Enumerarlos no es detalle: es la misma fila 47
/// veces, y lo que se pierde es justamente cuánto compraste ese día.
class LotGroup {
  final List<CostBasisLot> lots;

  LotGroup(this.lots);

  CostBasisLot get first => lots.first;
  String get id => first.id;
  String get exchange => first.exchange;
  String? get pair => first.pair;

  /// La del primer fill: es cuando pusiste la orden.
  DateTime get acquiredAt => lots.first.acquiredAt;

  int get count => lots.length;
  bool get isGrouped => lots.length > 1;

  double get remainingAmount =>
      lots.fold(0.0, (sum, l) => sum + l.remainingAmount);

  double get originalAmount =>
      lots.fold(0.0, (sum, l) => sum + l.originalAmount);

  double get remainingCost => lots.fold(0.0, (sum, l) => sum + l.remainingCost);

  /// Ponderado por lo que queda de cada lote, que es lo que este grupo aporta.
  /// Promediar los precios a secas daría un número que nadie pagó.
  double get costPerUnit =>
      remainingAmount > 0 ? remainingCost / remainingAmount : first.costPerUnit;

  double unrealizedAt(double price) => (price - costPerUnit) * remainingAmount;

  /// Alguno de los fills fue consumido en parte por una venta.
  bool get isPartial => originalAmount > remainingAmount;

  int get remainingPercent =>
      originalAmount > 0 ? (remainingAmount / originalAmount * 100).round() : 100;
}

/// Una venta, o los fills de una misma venta vistos como uno solo.
class SaleGroup {
  final List<RealizedPnlItem> sales;

  SaleGroup(this.sales);

  RealizedPnlItem get first => sales.first;
  String get id => first.id;
  String get exchange => first.exchange;
  DateTime get realizedAt => sales.first.realizedAt;

  int get count => sales.length;
  bool get isGrouped => sales.length > 1;

  double get amount => sales.fold(0.0, (sum, s) => sum + s.amount);
  double get realizedPnl => sales.fold(0.0, (sum, s) => sum + s.realizedPnl);
  double get costBasis => sales.fold(0.0, (sum, s) => sum + s.costBasis);
  double get proceeds => sales.fold(0.0, (sum, s) => sum + s.proceeds);

  double get buyPrice => amount > 0 ? costBasis / amount : first.buyPrice;
  double get sellPrice => amount > 0 ? proceeds / amount : first.sellPrice;

  double? get percent => costBasis > 0 ? (realizedPnl / costBasis) * 100 : null;
}

/// Junta los lotes que son fills de una misma compra.
///
/// El corte se mide contra el ÚLTIMO fill, no contra el primero: una ráfaga de
/// media hora es una orden que se fue ejecutando, y medir contra el primero la
/// partiría al minuto 15 en dos compras que nunca existieron.
List<LotGroup> groupLots(List<CostBasisLot> lots, {Duration window = kFillWindow}) {
  final sorted = [...lots]..sort((a, b) => a.acquiredAt.compareTo(b.acquiredAt));

  final groups = <List<CostBasisLot>>[];
  for (final lot in sorted) {
    final open = groups.isEmpty ? null : groups.last;
    final last = open?.last;

    // Un lote que entró vía NEXO/BTC no es un pedazo de una compra en BTC/USDT,
    // diga lo que diga el reloj.
    final sameOrder = open != null &&
        last!.exchange == lot.exchange &&
        last.pair == lot.pair &&
        last.source == lot.source &&
        lot.acquiredAt.difference(last.acquiredAt).abs() <= window;

    if (sameOrder) {
      open.add(lot);
    } else {
      groups.add([lot]);
    }
  }

  return groups.map(LotGroup.new).toList();
}

/// Junta las ventas que son fills de una misma orden de venta.
List<SaleGroup> groupSales(
  List<RealizedPnlItem> sales, {
  Duration window = kFillWindow,
}) {
  final sorted = [...sales]..sort((a, b) => a.realizedAt.compareTo(b.realizedAt));

  final groups = <List<RealizedPnlItem>>[];
  for (final sale in sorted) {
    final open = groups.isEmpty ? null : groups.last;
    final last = open?.last;

    final sameOrder = open != null &&
        last!.exchange == sale.exchange &&
        sale.realizedAt.difference(last.realizedAt).abs() <= window;

    if (sameOrder) {
      open.add(sale);
    } else {
      groups.add([sale]);
    }
  }

  return groups.map(SaleGroup.new).toList();
}
