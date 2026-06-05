import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  User? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;

  AuthService(this._apiService);

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) {
        _apiService.setAuthToken(token);

        // Try to load cached user
        final userJson = await _storage.read(key: _userKey);
        if (userJson != null) {
          _currentUser = User.fromJson(jsonDecode(userJson));
        }

        // Verify token is still valid by fetching current user
        try {
          await _fetchCurrentUser();
        } catch (e) {
          // Token is invalid, clear it
          await logout();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing auth: $e');
      }
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<User> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/auth/login',
        data: LoginRequest(email: email, password: password).toJson(),
      );

      final tokenResponse = TokenResponse.fromJson(response);
      await _storage.write(key: _tokenKey, value: tokenResponse.accessToken);
      _apiService.setAuthToken(tokenResponse.accessToken);

      await _fetchCurrentUser();

      return _currentUser!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchCurrentUser() async {
    final response = await _apiService.get<Map<String, dynamic>>('/auth/me');
    _currentUser = User.fromJson(response);
    await _storage.write(key: _userKey, value: jsonEncode(_currentUser!.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
      _apiService.setAuthToken(null);
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> getStoredToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<User> loginWithPasskey(Map<String, dynamic> tokenResponse) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = TokenResponse.fromJson(tokenResponse);
      await _storage.write(key: _tokenKey, value: response.accessToken);
      _apiService.setAuthToken(response.accessToken);

      await _fetchCurrentUser();

      return _currentUser!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
