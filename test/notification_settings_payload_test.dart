import 'package:exchange_monitor/core/config/app_config.dart';
import 'package:exchange_monitor/core/services/api_service.dart';
import 'package:exchange_monitor/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Qué manda la app al guardar los ajustes.
///
/// La selección de activos se carga de la API, así que hay un momento —entre
/// que abrís la pantalla y que contesta— en el que la app no sabe cuál es. Si
/// en ese hueco mandara la lista vacía, el backend la leería como "no quiero
/// que me avisen de nada" y te quedarías sin alertas sin haber tocado nada.
class _RecordingApiService extends ApiService {
  Map<String, dynamic>? ultimoPut;
  Map<String, dynamic> respuestaDeSettings = const {};
  bool falloAlCargar = false;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    if (falloAlCargar) throw Exception('sin red');
    return respuestaDeSettings as T;
  }

  @override
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    ultimoPut = Map<String, dynamic>.from(data as Map);
    return <String, dynamic>{} as T;
  }
}

void main() {
  setUpAll(() {
    AppConfig(
      flavor: Flavor.dev,
      apiBaseUrl: 'http://localhost:3050/api',
      wsBaseUrl: 'ws://localhost:3050',
      appName: 'test',
    );
  });

  test('sin haber cargado, guardar no manda la selección', () async {
    final api = _RecordingApiService();
    final service = NotificationService(api);

    await service.toggleEnabled(true);

    expect(
      api.ultimoPut!.containsKey('alertAssets'),
      isFalse,
      reason: 'omitirlo le dice a la API que no lo toque; '
          'mandar [] borraría la selección',
    );
  });

  test('si falla la carga tampoco la manda', () async {
    final api = _RecordingApiService()..falloAlCargar = true;
    final service = NotificationService(api);

    await service.loadSettings();
    await service.toggleEnabled(true);

    expect(api.ultimoPut!.containsKey('alertAssets'), isFalse);
  });

  test('una vez cargada, la manda tal cual', () async {
    final api = _RecordingApiService()
      ..respuestaDeSettings = {
        'enabled': true,
        'priceChangeThreshold': 5,
        'alertAssets': ['btc', 'eth'],
      };
    final service = NotificationService(api);

    await service.loadSettings();
    await service.setPriceChangeThreshold(3);

    expect(api.ultimoPut!['alertAssets'], ['BTC', 'ETH']);
  });

  test('vaciar la selección a propósito sí se manda', () async {
    final api = _RecordingApiService()
      ..respuestaDeSettings = {
        'enabled': true,
        'priceChangeThreshold': 5,
        'alertAssets': ['BTC'],
      };
    final service = NotificationService(api);

    await service.loadSettings();
    await service.setAssetFollowed('BTC', false);

    expect(api.ultimoPut!['alertAssets'], isEmpty);
    expect(service.alertAssets, isEmpty);
  });
}
