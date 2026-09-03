import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../core/services/passkey_service.dart';
import '../../../core/theme/em_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/em/em_primitives.dart';

class PasskeySettingsScreen extends StatefulWidget {
  const PasskeySettingsScreen({super.key});

  @override
  State<PasskeySettingsScreen> createState() => _PasskeySettingsScreenState();
}

class _PasskeySettingsScreenState extends State<PasskeySettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PasskeyService>().loadCredentials();
    });
  }

  Future<void> _register() async {
    final service = context.read<PasskeyService>();
    final ok = await service.registerPasskey();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Passkey creada en este dispositivo'
              : service.error ?? 'No se pudo crear la passkey',
        ),
      ),
    );
  }

  Future<void> _delete(PasskeyCredential credential) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar passkey'),
        content: Text(
          'No vas a poder entrar con "${credential.deviceName}" nunca más. '
          'Tu contraseña sigue funcionando.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: EmColors.down),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<PasskeyService>().deletePasskey(credential.id);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PasskeyService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Passkeys')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          EmSpace.screen,
          EmSpace.sm,
          EmSpace.screen,
          EmSpace.xxl,
        ),
        children: [
          Text(
            'Una passkey te deja entrar con Face ID o Touch ID, sin escribir la '
            'contraseña. Queda guardada en el dispositivo y no viaja a ningún lado.',
            style: EmText.body.copyWith(color: EmColors.textTertiary),
          ),
          const SizedBox(height: EmSpace.xl),

          EmSectionHeader(
            title: 'Tus passkeys',
            trailing: service.credentials.isEmpty
                ? null
                : '${service.credentials.length}',
          ),

          if (service.isLoading && service.credentials.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: EmSpace.xl),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (service.credentials.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: EmSpace.md),
              child: Text(
                'Todavía no hay ninguna en esta cuenta.',
                style: EmText.label.copyWith(color: EmColors.textTertiary),
              ),
            )
          else
            for (final credential in service.credentials)
              EmListRow(
                leading: _ProveedorTile(credential: credential),
                title: credential.deviceName,
                subtitle: credential.lastUsedAt != null
                    ? 'Último uso ${formatRelative(credential.lastUsedAt!)}'
                    : 'Creada ${formatRelative(credential.createdAt)}',
                showDivider: credential != service.credentials.last,
                trailing: GestureDetector(
                  onTap: () => _delete(credential),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(EmSpace.sm),
                    child: Icon(
                      Icons.delete_outline,
                      size: 19,
                      color: EmColors.textTertiary,
                    ),
                  ),
                ),
              ),

          const SizedBox(height: EmSpace.xl),
          OutlinedButton.icon(
            onPressed: service.isLoading || !service.isSupported ? null : _register,
            icon: const Icon(Icons.add, size: 19),
            label: const Text('Agregar passkey'),
          ),
          if (!service.isSupported) ...[
            const SizedBox(height: EmSpace.md),
            Text(
              'Este dispositivo no admite passkeys.',
              style: EmText.meta,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// El cuadradito de la izquierda: el logo de quien guarda la llave, y la llave
/// genérica para los que no declaran proveedor —que es justo lo que esa llave
/// significa ahora—. Mismas medidas que [EmIconTile] para que las filas no se
/// desalineen entre sí.
class _ProveedorTile extends StatelessWidget {
  final PasskeyCredential credential;

  const _ProveedorTile({required this.credential});

  /// Se manda el ALTO y el ancho lo pone la proporción del dibujo: dándole los
  /// dos, flutter_svg ajusta por alto y deja que el ancho se desborde —así la
  /// llave de Google, que es 1,82:1, salía a 25 puntos en una caja de 28 y se
  /// quedaba sin aire—.
  ///
  /// 14 es la mitad del cuadradito, igual que el ícono de [EmIconTile], y sirve
  /// para las marcas cuadradas. Una horizontal necesita su propio alto para
  /// terminar midiendo lo mismo a lo ancho.
  static const _altoBase = 14.0;
  static const _altoCorregido = {'google-password-manager': 11.0};

  static double _alto(String? providerId) =>
      _altoCorregido[providerId] ?? _altoBase;

  @override
  Widget build(BuildContext context) {
    final logo = credential.logoAsset;
    if (logo == null) {
      return const EmIconTile(
        icon: Icons.key_outlined,
        color: EmColors.textSecondary,
        tinted: false,
      );
    }

    return Semantics(
      label: credential.provider,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: EmColors.surfaceHigh,
          borderRadius: BorderRadius.circular(EmRadii.sm),
        ),
        child: SvgPicture.asset(
          logo,
          height: _alto(credential.providerId),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
