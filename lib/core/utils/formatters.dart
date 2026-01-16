/// Utility functions for formatting data

/// Formats exchange name for display
/// e.g., "binance" -> "Binance", "nexo-manual" -> "Nexo Manual", "kraken" -> "Kraken"
String formatExchangeName(String exchange) {
  final normalized = exchange.toLowerCase();

  // Handle special cases
  if (normalized == 'nexo-manual') {
    return 'Nexo Manual';
  }
  if (normalized == 'nexo-pro') {
    return 'Nexo Pro';
  }

  // Capitalize first letter
  if (normalized.isEmpty) return exchange;
  return normalized[0].toUpperCase() + normalized.substring(1);
}
