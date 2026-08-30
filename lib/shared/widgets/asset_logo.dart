import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/em_tokens.dart';

class AssetLogo extends StatelessWidget {
  final String asset;
  final double size;
  final bool showFallback;

  const AssetLogo({
    super.key,
    required this.asset,
    this.size = 32,
    this.showFallback = true,
  });

  String get _normalizedAsset {
    var normalized = asset.toLowerCase();
    // Handle Binance locked staking assets (e.g., LDBTC -> btc)
    if (normalized.startsWith('ld') && normalized.length > 2) {
      normalized = normalized.substring(2);
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: _buildLogo(),
    );
  }

  Widget _buildLogo() {
    return SvgPicture.asset(
      'assets/logos/$_normalizedAsset.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (context) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    if (!showFallback) {
      return const SizedBox.shrink();
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: EmColors.surfaceHigh,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: EmColors.stroke)),
      ),
      child: Center(
        child: Text(
          asset.length >= 2 ? asset.substring(0, 2).toUpperCase() : asset.toUpperCase(),
          style: TextStyle(
            color: EmColors.textSecondary,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Widget that displays two logos for a trading pair (e.g., BTC/USDT)
/// The primary asset logo is larger, and the quote logo is smaller
/// positioned at the bottom-right corner
class PairLogos extends StatelessWidget {
  final String asset;
  final String quote;
  final double size;

  const PairLogos({
    super.key,
    required this.asset,
    required this.quote,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final primarySize = size * 0.9;
    final secondarySize = size * 0.45;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Primary logo (base asset)
          Positioned(
            left: 0,
            top: 0,
            child: AssetLogo(
              asset: asset,
              size: primarySize,
            ),
          ),
          // Secondary logo (quote currency) - bottom right with border
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: EmColors.bg,
                shape: BoxShape.circle,
                border: Border.all(color: EmColors.bg, width: 2),
              ),
              child: AssetLogo(
                asset: quote,
                size: secondarySize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExchangeLogo extends StatelessWidget {
  final String exchange;
  final double size;

  const ExchangeLogo({
    super.key,
    required this.exchange,
    this.size = 24,
  });

  String get _normalizedExchange {
    return exchange.toLowerCase().replaceAll('_', '-');
  }

  Color get _exchangeColor {
    switch (exchange.toLowerCase()) {
      default:
        return EmColors.brandOf(exchange) ?? EmColors.surfaceHigh;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/logos/$_normalizedExchange.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _exchangeColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          exchange.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
