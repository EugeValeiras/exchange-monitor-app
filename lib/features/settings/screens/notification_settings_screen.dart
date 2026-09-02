import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/balance_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/asset_logo.dart';
import '../../../shared/widgets/em/em_primitives.dart';

/// Notificaciones.
///
/// La hoja de bienvenida prometía "horarios personalizados" y "ajustá el
/// umbral de cambio", y la pantalla real tenía un único interruptor. El
/// servicio y la API ya soportaban las dos cosas: acá están.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  static const _thresholds = [1, 3, 5, 10];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<NotificationService>();
      service.loadSettings();
      service.refreshPermissionStatus();
      // La lista de activos elegibles sale de la cartera: si entraste directo
      // acá sin pasar por Posición, todavía no está cargada.
      final balance = context.read<BalanceService>();
      if (!balance.hasData) balance.loadBalance();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Volver de Ajustes de iOS con el permiso recién concedido tiene que
    // reflejarse acá sin reiniciar la app.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<NotificationService>().refreshPermissionStatus();
    }
  }

  Future<void> _requestPermission() async {
    final service = context.read<NotificationService>();
    final granted = await service.requestPermissionAndSetup();
    if (granted) await service.registerTokenAfterLogin();
  }

  Future<void> _pickQuietHour({required bool isStart}) async {
    final service = context.read<NotificationService>();
    final current = isStart ? service.quietHoursStart : service.quietHoursEnd;

    final initial = _parse(current) ?? TimeOfDay(hour: isStart ? 23 : 8, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;

    final formatted = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    await service.setQuietHours(
      isStart ? formatted : service.quietHoursStart,
      isStart ? service.quietHoursEnd : formatted,
    );
  }

  TimeOfDay? _parse(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NotificationService>();
    final hasQuietHours =
        service.quietHoursStart != null && service.quietHoursEnd != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          EmSpace.screen,
          EmSpace.sm,
          EmSpace.screen,
          EmSpace.xxl,
        ),
        children: [
          if (!service.hasPermission) ...[
            Container(
              padding: const EdgeInsets.all(EmSpace.lg),
              decoration: BoxDecoration(
                color: EmColors.surface,
                borderRadius: BorderRadius.circular(EmRadii.card),
                border: Border.all(color: EmColors.stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sin permiso del sistema', style: EmText.headline),
                  const SizedBox(height: EmSpace.sm - 2),
                  Text(
                    'iOS todavía no autorizó las notificaciones de la app, '
                    'así que no vas a recibir avisos aunque estén activados acá.',
                    style: EmText.body.copyWith(color: EmColors.textTertiary),
                  ),
                  const SizedBox(height: EmSpace.lg),
                  ElevatedButton(
                    onPressed: _requestPermission,
                    child: const Text('Permitir notificaciones'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: EmSpace.xl),
          ],

          const EmSectionHeader(title: 'Alertas'),
          _SwitchRow(
            title: 'Cambios de precio',
            subtitle: 'Un aviso cuando un activo tuyo se mueve fuerte',
            value: service.enabled,
            onChanged: service.toggleEnabled,
          ),

          const SizedBox(height: EmSpace.xl),
          EmSectionHeader(
            title: 'Umbral',
            trailing: '${service.priceChangeThreshold} %',
          ),
          const SizedBox(height: EmSpace.sm + 2),
          Opacity(
            opacity: service.enabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !service.enabled,
              child: EmSegmented<int>(
                options: [
                  for (final t in _thresholds) (value: t, label: '$t %'),
                ],
                selected: service.priceChangeThreshold,
                onChanged: service.setPriceChangeThreshold,
              ),
            ),
          ),
          const SizedBox(height: EmSpace.sm + 2),
          Text(
            'Por debajo de este movimiento en 24 h no te avisamos.',
            style: EmText.meta,
          ),

          const SizedBox(height: EmSpace.xl),
          _AssetPicker(enabled: service.enabled),

          const SizedBox(height: EmSpace.xl),
          EmSectionHeader(
            title: 'Horas de silencio',
            trailing: hasQuietHours ? 'quitar' : null,
            onTrailingTap:
                hasQuietHours ? () => service.setQuietHours(null, null) : null,
          ),
          Opacity(
            opacity: service.enabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !service.enabled,
              child: Column(
                children: [
                  EmListRow(
                    title: 'Desde',
                    value: service.quietHoursStart ?? '—',
                    onTap: () => _pickQuietHour(isStart: true),
                  ),
                  EmListRow(
                    title: 'Hasta',
                    value: service.quietHoursEnd ?? '—',
                    onTap: () => _pickQuietHour(isStart: false),
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: EmSpace.sm + 2),
          Text(
            'En esa franja no llega ningún aviso.',
            style: EmText.meta,
          ),
        ],
      ),
    );
  }
}

/// Qué activos avisan.
///
/// La lista sale de tu cartera, no de un catálogo: el aviso es sobre tu plata.
/// Se suman los que ya estaban elegidos aunque hoy no tengas saldo, para que
/// vender todo de algo no borre en silencio una elección tuya.
class _AssetPicker extends StatelessWidget {
  final bool enabled;

  const _AssetPicker({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NotificationService>();
    final balance = context.watch<BalanceService>();

    final held = balance.sortedAssetsByValue;
    final heldTickers = held.map((a) => a.asset.toUpperCase()).toList();
    final orphans = service.alertAssets
        .where((a) => !heldTickers.contains(a))
        .toList()
      ..sort();

    final rows = <({String asset, double? valueUsd})>[
      for (final a in held) (asset: a.asset.toUpperCase(), valueUsd: a.valueUsd),
      for (final a in orphans) (asset: a, valueUsd: null),
    ];

    final selected = rows.where((r) => service.followsAsset(r.asset)).length;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmSectionHeader(
              title: 'Activos',
              trailing: rows.isEmpty ? null : '$selected de ${rows.length}',
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: EmSpace.md),
                child: Text(
                  'Cuando cargue tu cartera vas a poder elegir acá.',
                  style: EmText.label.copyWith(color: EmColors.textTertiary),
                ),
              )
            else
              for (final row in rows)
                EmListRow(
                  leading: AssetLogo(asset: row.asset, size: 32),
                  title: row.asset,
                  subtitle: row.valueUsd == null
                      ? 'sin saldo'
                      : formatUsd(row.valueUsd!),
                  showDivider: row != rows.last,
                  trailing: Switch(
                    value: service.followsAsset(row.asset),
                    onChanged: (value) =>
                        service.setAssetFollowed(row.asset, value),
                  ),
                  onTap: () => service.setAssetFollowed(
                    row.asset,
                    !service.followsAsset(row.asset),
                  ),
                ),
            const SizedBox(height: EmSpace.sm + 2),
            Text(
              selected == 0 && rows.isNotEmpty
                  ? 'Sin ningún activo elegido no llega ningún aviso.'
                  : 'Sólo avisamos de los activos marcados.',
              style: EmText.meta,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return EmListRow(
      title: title,
      subtitle: subtitle,
      showDivider: false,
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}
