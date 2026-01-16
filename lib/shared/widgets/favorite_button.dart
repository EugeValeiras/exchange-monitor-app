import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/favorites_service.dart';
import '../../core/theme/app_theme.dart';

class FavoriteButton extends StatefulWidget {
  final String asset;
  final double size;

  const FavoriteButton({
    super.key,
    required this.asset,
    this.size = 24,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    final favoritesService = context.read<FavoritesService>();
    final wasFavorite = favoritesService.isFavorite(widget.asset);

    setState(() => _isLoading = true);

    final isFavorite = await favoritesService.toggleFavorite(widget.asset);

    if (mounted) {
      setState(() => _isLoading = false);

      // Play pop animation when adding to favorites
      if (isFavorite && !wasFavorite) {
        _animationController.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesService = context.watch<FavoritesService>();
    final isFavorite = favoritesService.isFavorite(widget.asset);

    return GestureDetector(
      onTap: _toggleFavorite,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: _isLoading ? 0.5 : 1.0,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                size: widget.size,
                color: isFavorite
                    ? const Color(0xFFF59E0B) // Amber color
                    : AppColors.textTertiary,
              ),
            );
          },
        ),
      ),
    );
  }
}
