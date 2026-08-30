import 'package:intl/intl.dart';

/// Formateo de números, montos y fechas.
///
/// Reglas del sistema:
///  - Formato es-AR: punto para miles, coma para decimales.
///  - El signo menos es el tipográfico (−, U+2212), no el guion: alinea con el
///    más y no se confunde con un separador.
///  - Una cotización lleva el símbolo de SU moneda. Un par NEXO/BTC no se
///    escribe con "$": no son dólares.
const String kMinus = '−';

const _localeEs = 'es_AR';

/// Monedas que se muestran con el prefijo "$" y dos decimales.
const _dollarQuotes = {'USD', 'USDT', 'USDC', 'BUSD', 'DAI', 'TUSD', 'USDP'};

bool isDollarQuote(String quote) => _dollarQuotes.contains(quote.toUpperCase());

/// "105.129,91". Sin símbolo: el contexto ya dice que son dólares.
String formatMoney(double value, {int decimals = 2}) {
  final f = NumberFormat.decimalPatternDigits(
    locale: _localeEs,
    decimalDigits: decimals,
  );
  return f.format(value);
}

/// "$105.129,91".
String formatUsd(double value, {int decimals = 2}) => '\$${formatMoney(value, decimals: decimals)}';

/// Monto con signo explícito: "+1.234,56" / "−1.234,56".
String formatSignedMoney(double value, {int decimals = 2}) {
  final sign = value < 0 ? kMinus : '+';
  return '$sign${formatMoney(value.abs(), decimals: decimals)}';
}

/// Monto con signo y símbolo: "+$1.234,56" / "−$1.234,56".
///
/// Para un número que aparece SOLO, sin una columna de valores que lo
/// contextualice: sin el símbolo, "+301" se lee tan fácil como un porcentaje o
/// un conteo. En listas alineadas a la derecha alcanza con [formatSignedMoney].
String formatSignedUsd(double value, {int decimals = 2}) {
  final sign = value < 0 ? kMinus : '+';
  return '$sign\$${formatMoney(value.abs(), decimals: decimals)}';
}

/// Porcentaje con signo: "+2,50%" / "−2,50%".
String formatSignedPercent(double value, {int decimals = 2}) {
  final sign = value < 0 ? kMinus : '+';
  return '$sign${formatMoney(value.abs(), decimals: decimals)}%';
}

/// Porcentaje sin signo positivo: "2,50%".
String formatPercent(double value, {int decimals = 2}) =>
    '${formatMoney(value.abs(), decimals: decimals)}%';

/// Cantidad de un activo, con la precisión que ese activo merece: no tiene
/// sentido mostrar 8 decimales de USDT ni 2 de BTC.
String formatAssetAmount(double amount, {int? decimals}) {
  final d = decimals ?? _decimalsForAmount(amount);
  return formatMoney(amount, decimals: d);
}

int _decimalsForAmount(double amount) {
  final abs = amount.abs();
  if (abs == 0) return 2;
  if (abs >= 1000) return 2;
  if (abs >= 1) return 4;
  if (abs >= 0.01) return 6;
  return 8;
}

/// Cantidad + ticker: "1,0790 BTC".
String formatAssetQuantity(double amount, String asset, {int? decimals}) =>
    '${formatAssetAmount(amount, decimals: decimals)} ${asset.toUpperCase()}';

/// Cantidad con signo + ticker: "+0,5790 BTC" / "−0,5790 BTC".
String formatSignedQuantity(double amount, String asset, {int? decimals}) {
  final sign = amount < 0 ? kMinus : '+';
  return '$sign${formatAssetAmount(amount.abs(), decimals: decimals)} ${asset.toUpperCase()}';
}

/// Un precio SIEMPRE se muestra en la moneda en la que cotiza.
///
///   BTC/USDT  → "$77.697,05"
///   NEXO/BTC  → "0,00001058 BTC"
///
/// Antes esta app formateaba todo con `symbol: '$'`, así que un par cotizado en
/// BTC aparecía como "$0,000011" — un número que no significaba nada.
String formatQuotePrice(double price, String quote) {
  if (isDollarQuote(quote)) {
    return formatUsd(price, decimals: _decimalsForPrice(price));
  }
  return '${formatAssetAmount(price, decimals: _decimalsForCryptoQuote(price))} ${quote.toUpperCase()}';
}

/// Igual que [formatQuotePrice] pero devuelve número y unidad por separado,
/// para poder darle a la unidad un peso tipográfico menor.
({String value, String? unit}) splitQuotePrice(double price, String quote) {
  if (isDollarQuote(quote)) {
    return (value: formatUsd(price, decimals: _decimalsForPrice(price)), unit: null);
  }
  return (
    value: formatAssetAmount(price, decimals: _decimalsForCryptoQuote(price)),
    unit: quote.toUpperCase(),
  );
}

int _decimalsForPrice(double price) {
  final abs = price.abs();
  if (abs >= 1000) return 2;
  if (abs >= 1) return 2;
  if (abs >= 0.01) return 4;
  return 6;
}

int _decimalsForCryptoQuote(double price) {
  final abs = price.abs();
  if (abs >= 1) return 4;
  if (abs >= 0.0001) return 6;
  return 8;
}

/// Compacta un monto grande para un espacio chico: "105,1 K", "1,2 M".
String formatCompactMoney(double value) {
  final abs = value.abs();
  final sign = value < 0 ? kMinus : '';
  if (abs >= 1000000) return '$sign${formatMoney(abs / 1000000, decimals: 1)} M';
  if (abs >= 10000) return '$sign${formatMoney(abs / 1000, decimals: 1)} K';
  return '$sign${formatMoney(abs, decimals: 0)}';
}

// ---------------------------------------------------------------------------
// Fechas. Todo en español; requiere initializeDateFormatting('es') en el
// arranque (ver main_common.dart).
// ---------------------------------------------------------------------------

/// "24 ago 19:48".
String formatDateTimeShort(DateTime dt) =>
    DateFormat("d MMM HH:mm", 'es').format(dt.toLocal());

/// "19:48".
String formatTime(DateTime dt) => DateFormat('HH:mm', 'es').format(dt.toLocal());

/// "24 ago".
String formatDayShort(DateTime dt) => DateFormat('d MMM', 'es').format(dt.toLocal());

/// Encabezado de un grupo de movimientos: "Hoy", "Ayer" o
/// "Domingo 24 de agosto" (con el año si no es el actual).
String formatDayHeader(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;

  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';

  final pattern = local.year == now.year ? "EEEE d 'de' MMMM" : "EEEE d 'de' MMMM 'de' y";
  final text = DateFormat(pattern, 'es').format(local);
  return text[0].toUpperCase() + text.substring(1);
}

/// "hace 2 min", "hace 3 h", "ayer".
String formatRelative(DateTime dt) {
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inSeconds < 60) return 'recién';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays == 1) return 'ayer';
  return formatDayShort(dt);
}

// ---------------------------------------------------------------------------
// Nombres
// ---------------------------------------------------------------------------

/// "binance" → "Binance", "nexo-manual" → "Nexo", "kraken" → "Kraken".
String formatExchangeName(String exchange) {
  final normalized = exchange.toLowerCase();

  if (normalized == 'nexo-manual') return 'Nexo';
  if (normalized == 'nexo-pro') return 'Nexo Pro';

  if (normalized.isEmpty) return exchange;
  return normalized[0].toUpperCase() + normalized.substring(1);
}

/// Lista de exchanges legible: "Binance, Nexo" o "3 exchanges" si son muchos.
String formatExchangeList(List<String> exchanges) {
  if (exchanges.isEmpty) return '';
  final names = exchanges.map(formatExchangeName).toSet().toList();
  if (names.length > 2) return '${names.length} exchanges';
  return names.join(', ');
}

const _assetNames = <String, String>{
  'BTC': 'Bitcoin',
  'ETH': 'Ethereum',
  'USDT': 'Tether',
  'USDC': 'USD Coin',
  'NEXO': 'Nexo',
  'SOL': 'Solana',
  'XRP': 'XRP',
  'ADA': 'Cardano',
  'DOT': 'Polkadot',
  'MATIC': 'Polygon',
  'AVAX': 'Avalanche',
  'LINK': 'Chainlink',
  'DOGE': 'Dogecoin',
  'LTC': 'Litecoin',
  'BNB': 'BNB',
  'AXS': 'Axie Infinity',
  'MON': 'Monad',
  'USD': 'Dólar',
};

/// Nombre largo del activo, o el ticker si no lo conocemos.
String assetName(String asset) => _assetNames[asset.toUpperCase()] ?? asset.toUpperCase();
