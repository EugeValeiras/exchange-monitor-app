import 'package:flutter/foundation.dart';
import 'api_service.dart';

class FavoritesService extends ChangeNotifier {
  final ApiService _apiService;

  List<String> _favorites = [];
  bool _isLoading = false;
  String? _error;

  FavoritesService(this._apiService);

  List<String> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFavorites => _favorites.isNotEmpty;

  /// Load favorites from API
  Future<void> loadFavorites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/favorites');
      final List<dynamic> favoritesJson = response['favorites'] ?? [];
      _favorites = favoritesJson.cast<String>();
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error loading favorites: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle favorite status for an asset
  Future<bool> toggleFavorite(String asset) async {
    try {
      final response = await _apiService.post('/favorites/${asset.toUpperCase()}/toggle');
      final List<dynamic> favoritesJson = response['favorites'] ?? [];
      _favorites = favoritesJson.cast<String>();
      notifyListeners();
      return response['isFavorite'] ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling favorite: $e');
      }
      return false;
    }
  }

  /// Check if an asset is a favorite
  bool isFavorite(String asset) {
    return _favorites.contains(asset.toUpperCase());
  }

  /// Get first N favorites
  List<String> getTopFavorites(int count) {
    return _favorites.take(count).toList();
  }
}
