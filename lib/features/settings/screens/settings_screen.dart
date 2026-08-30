import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/balance_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/em/em_primitives.dart';
import 'notification_settings_screen.dart';
import 'passkey_settings_screen.dart';

/// Ajustes.
///
/// Antes esto era una hoja con dos ítems y "Cerrar Sesion": no había dónde ver
/// qué exchanges estaban conectados, ni qué versión corría el teléfono.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final balance = context.watch<BalanceService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          EmSpace.screen,
          EmSpace.sm,
          EmSpace.screen,
          EmSpace.xxl,
        ),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: EmColors.surfaceTop,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(BorderSide(color: EmColors.stroke)),
                ),
                child: Text(
                  user?.initials ?? '?',
                  style: EmText.headline.copyWith(color: EmColors.textSecondary),
                ),
              ),
              const SizedBox(width: EmSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.fullName ?? 'Tu cuenta', style: EmText.headline),
                    const SizedBox(height: 2),
                    Text(user?.email ?? '', style: EmText.meta),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EmSpace.xl),

          const EmSectionHeader(title: 'Cuenta'),
          EmListRow(
            leading: const EmIconTile(
              icon: Icons.notifications_none,
              color: EmColors.textSecondary,
              tinted: false,
            ),
            title: 'Notificaciones',
            subtitle: 'Alertas de cambios de precio',
            showChevron: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
          EmListRow(
            leading: const EmIconTile(
              icon: Icons.fingerprint,
              color: EmColors.textSecondary,
              tinted: false,
            ),
            title: 'Passkeys',
            subtitle: 'Entrar con Face ID en vez de contraseña',
            showChevron: true,
            showDivider: false,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PasskeySettingsScreen()),
            ),
          ),

          const SizedBox(height: EmSpace.xl),
          EmSectionHeader(
            title: 'Exchanges',
            trailing: balance.exchanges.isEmpty ? null : 'sólo lectura',
          ),
          if (balance.exchanges.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: EmSpace.md),
              child: Text(
                'Todavía no hay exchanges conectados.',
                style: EmText.label.copyWith(color: EmColors.textTertiary),
              ),
            )
          else
            for (final exchange in balance.exchanges)
              EmListRow(
                title: formatExchangeName(exchange.exchange),
                subtitle: '${exchange.balances.length} '
                    '${exchange.balances.length == 1 ? 'activo' : 'activos'}',
                value: formatMoney(exchange.totalValueUsd),
                showDivider: exchange != balance.exchanges.last,
              ),

          const SizedBox(height: EmSpace.xl),
          const EmSectionHeader(title: 'Aplicación'),
          const _VersionRow(),
          EmListRow(
            title: 'Cerrar sesión',
            showDivider: false,
            onTap: () => _confirmLogout(context),
            trailing: const Icon(
              Icons.logout,
              size: 18,
              color: EmColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthService>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('Vas a tener que volver a entrar en este dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: EmColors.down),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await auth.logout();
    }
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return EmListRow(
          title: 'Versión',
          value: info == null ? '—' : '${info.version} (${info.buildNumber})',
        );
      },
    );
  }
}
