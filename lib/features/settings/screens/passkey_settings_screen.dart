import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/passkey_service.dart';

class PasskeySettingsScreen extends StatefulWidget {
  const PasskeySettingsScreen({super.key});

  @override
  State<PasskeySettingsScreen> createState() => _PasskeySettingsScreenState();
}

class _PasskeySettingsScreenState extends State<PasskeySettingsScreen> {
  final _deviceNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPasskeys();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPasskeys() async {
    await context.read<PasskeyService>().loadCredentials();
  }

  Future<void> _registerPasskey() async {
    final deviceName = await _showDeviceNameDialog();
    if (deviceName == null) return;

    final passkeyService = context.read<PasskeyService>();
    final success = await passkeyService.registerPasskey(deviceName: deviceName);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passkey registrado correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted && passkeyService.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(passkeyService.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _showDeviceNameDialog() async {
    _deviceNameController.clear();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('Nombre del dispositivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa un nombre para identificar este dispositivo',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deviceNameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ej: iPhone 15 Pro',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _deviceNameController.text.trim();
              Navigator.pop(context, name.isEmpty ? 'Dispositivo' : name);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePasskey(PasskeyCredential credential) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('Eliminar Passkey'),
        content: Text(
          'Deseas eliminar el passkey "${credential.deviceName}"?\n\nNo podras usar este dispositivo para iniciar sesion sin contrasena.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final passkeyService = context.read<PasskeyService>();
      final success = await passkeyService.deletePasskey(credential.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Passkey eliminado'),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (passkeyService.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(passkeyService.error!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final passkeyService = context.watch<PasskeyService>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgElevated,
        title: const Text('Passkeys'),
      ),
      body: passkeyService.isLoading && passkeyService.credentials.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPasskeys,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.bgTertiary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.fingerprint,
                                color: AppColors.brandAccent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Que son los Passkeys?',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Los passkeys te permiten iniciar sesion usando Face ID, Touch ID o huella dactilar, sin necesidad de recordar tu contrasena. Son mas seguros y faciles de usar.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Support status
                  if (!passkeyService.isSupported) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_rounded, color: AppColors.warning),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tu dispositivo no soporta passkeys',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Error message
                  if (passkeyService.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              passkeyService.error!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: AppColors.error,
                            onPressed: () => passkeyService.clearError(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Section title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tus Passkeys',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                      Text(
                        '${passkeyService.credentials.length}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Passkeys list
                  if (passkeyService.credentials.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.key_off_outlined,
                            color: AppColors.textTertiary,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No tienes passkeys registrados',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Agrega uno para iniciar sesion sin contrasena',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: passkeyService.credentials.asMap().entries.map((entry) {
                          final index = entry.key;
                          final credential = entry.value;
                          final isLast = index == passkeyService.credentials.length - 1;

                          return Column(
                            children: [
                              _PasskeyTile(
                                credential: credential,
                                onDelete: () => _deletePasskey(credential),
                              ),
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  color: AppColors.border,
                                  indent: 72,
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Add passkey button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: passkeyService.isSupported && !passkeyService.isLoading
                          ? _registerPasskey
                          : null,
                      icon: passkeyService.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.bgPrimary,
                              ),
                            )
                          : const Icon(Icons.add),
                      label: Text(
                        passkeyService.isLoading ? 'Registrando...' : 'Agregar Passkey',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PasskeyTile extends StatelessWidget {
  final PasskeyCredential credential;
  final VoidCallback onDelete;

  const _PasskeyTile({
    required this.credential,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.key,
              color: AppColors.brandAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credential.deviceName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Creado: ${dateFormat.format(credential.createdAt)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (credential.lastUsedAt != null)
                  Text(
                    'Ultimo uso: ${dateFormat.format(credential.lastUsedAt!)}',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: AppColors.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
