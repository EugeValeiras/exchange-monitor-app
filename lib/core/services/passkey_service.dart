import 'package:flutter/foundation.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import 'api_service.dart';

class PasskeyCredential {
  final String id;
  final String deviceName;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  PasskeyCredential({
    required this.id,
    required this.deviceName,
    required this.createdAt,
    this.lastUsedAt,
  });

  factory PasskeyCredential.fromJson(Map<String, dynamic> json) {
    return PasskeyCredential(
      id: json['id'] as String,
      deviceName: json['deviceName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
    );
  }
}

class PasskeyService extends ChangeNotifier {
  final ApiService _apiService;
  final PasskeyAuthenticator _authenticator;

  bool _isSupported = false;
  bool _isLoading = false;
  List<PasskeyCredential> _credentials = [];
  String? _error;

  PasskeyService(this._apiService)
      : _authenticator = PasskeyAuthenticator();

  bool get isSupported => _isSupported;
  bool get isLoading => _isLoading;
  List<PasskeyCredential> get credentials => _credentials;
  String? get error => _error;
  bool get hasPasskeys => _credentials.isNotEmpty;

  Future<void> checkSupport() async {
    try {
      final availability = _authenticator.getAvailability();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosAvail = await availability.iOS();
        _isSupported = iosAvail.hasPasskeySupport;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidAvail = await availability.android();
        _isSupported = androidAvail.hasPasskeySupport;
      } else {
        _isSupported = false;
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Passkey support check failed: $e');
      }
      _isSupported = false;
      notifyListeners();
    }
  }

  Future<void> loadCredentials() async {
    if (_apiService.authToken == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/auth/passkey/list',
      );

      final passkeys = (response['passkeys'] as List)
          .map((p) => PasskeyCredential.fromJson(p as Map<String, dynamic>))
          .toList();

      _credentials = passkeys;
    } on ApiException catch (e) {
      _error = e.message;
      if (kDebugMode) {
        print('Failed to load passkeys: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerPasskey({String? deviceName}) async {
    if (!_isSupported) {
      _error = 'Passkeys not supported on this device';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Get registration challenge from backend
      final challengeResponse = await _apiService.post<Map<String, dynamic>>(
        '/auth/passkey/register/challenge',
      );

      final options = challengeResponse['options'] as Map<String, dynamic>;

      // Build exclude credentials list
      final excludeCredentials = _buildCredentialsList(options['excludeCredentials']);

      // Step 2: Create credential using platform authenticator
      final registerResponse = await _authenticator.register(
        RegisterRequestType(
          challenge: options['challenge'] as String,
          relyingParty: RelyingPartyType(
            name: 'Exchange Monitor',
            id: options['rp']['id'] as String,
          ),
          user: UserType(
            id: options['user']['id'] as String,
            name: options['user']['name'] as String,
            displayName: options['user']['displayName'] as String,
          ),
          authSelectionType: AuthenticatorSelectionType(
            authenticatorAttachment: 'platform',
            residentKey: 'required',
            requireResidentKey: true,
            userVerification: 'required',
          ),
          timeout: options['timeout'] as int? ?? 60000,
          excludeCredentials: excludeCredentials,
        ),
      );

      // Step 3: Send response to backend for verification
      final verifyResponse = await _apiService.post<Map<String, dynamic>>(
        '/auth/passkey/register/verify',
        data: {
          'response': registerResponse.toJson(),
          'deviceName': deviceName ?? _getDeviceName(),
        },
      );

      if (verifyResponse['success'] == true) {
        await loadCredentials();
        return true;
      }

      _error = 'Registration verification failed';
      return false;
    } on PasskeyAuthCancelledException {
      _error = 'Registration was cancelled';
      return false;
    } on ExcludeCredentialsCanNotBeRegisteredException {
      _error = 'This device already has a passkey registered';
      return false;
    } on DomainNotAssociatedException catch (e) {
      _error = 'Domain not associated: ${e.message}';
      if (kDebugMode) {
        print('Domain not associated: ${e.message}');
      }
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      if (kDebugMode) {
        print('Passkey registration API error: $e');
      }
      return false;
    } catch (e) {
      _error = 'Registration failed: $e';
      if (kDebugMode) {
        print('Passkey registration error: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> authenticateWithPasskey({String? email}) async {
    if (!_isSupported) {
      _error = 'Passkeys not supported on this device';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Get authentication challenge from backend
      final challengeResponse = await _apiService.post<Map<String, dynamic>>(
        '/auth/passkey/authenticate/challenge',
        data: email != null ? {'email': email} : {},
      );

      final options = challengeResponse['options'] as Map<String, dynamic>;

      // Build allow credentials list (empty for discoverable credentials)
      final allowCredentials = _buildCredentialsList(options['allowCredentials']);

      // Step 2: Authenticate using platform authenticator
      final authResponse = await _authenticator.authenticate(
        AuthenticateRequestType(
          challenge: options['challenge'] as String,
          relyingPartyId: options['rpId'] as String,
          timeout: options['timeout'] as int? ?? 60000,
          userVerification: 'required',
          allowCredentials: allowCredentials.isEmpty ? null : allowCredentials,
          mediation: MediationType.Optional,
          preferImmediatelyAvailableCredentials: true,
        ),
      );

      // Step 3: Send response to backend for verification
      final Map<String, dynamic> verifyData = {
        'response': authResponse.toJson(),
      };

      if (email != null) {
        verifyData['email'] = email;
      }

      final verifyResponse = await _apiService.post<Map<String, dynamic>>(
        '/auth/passkey/authenticate/verify',
        data: verifyData,
      );

      return verifyResponse;
    } on PasskeyAuthCancelledException {
      _error = 'Authentication was cancelled';
      return null;
    } on NoCredentialsAvailableException {
      _error = 'No passkeys available for this account';
      return null;
    } on DomainNotAssociatedException catch (e) {
      _error = 'Domain not associated: ${e.message}';
      if (kDebugMode) {
        print('Domain not associated: ${e.message}');
      }
      return null;
    } on ApiException catch (e) {
      _error = e.message;
      if (kDebugMode) {
        print('Passkey authentication API error: $e');
      }
      return null;
    } catch (e) {
      _error = 'Authentication failed: $e';
      if (kDebugMode) {
        print('Passkey authentication error: $e');
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deletePasskey(String credentialId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final encodedId = Uri.encodeComponent(credentialId);
      await _apiService.delete<Map<String, dynamic>>(
        '/auth/passkey/$encodedId',
      );

      _credentials.removeWhere((c) => c.id == credentialId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      if (kDebugMode) {
        print('Failed to delete passkey: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<CredentialType> _buildCredentialsList(dynamic credentials) {
    if (credentials == null) return [];
    return (credentials as List).map((c) {
      final transports = c['transports'] as List?;
      return CredentialType(
        type: 'public-key',
        id: c['id'] as String,
        transports: transports?.cast<String>() ?? ['internal'],
      );
    }).toList();
  }

  String _getDeviceName() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'iPhone';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Android Device';
    }
    return 'Mobile Device';
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
