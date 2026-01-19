import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/widgets/notification_permission_sheet.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      await context.read<NotificationService>().loadSettings();
    } catch (e) {
      setState(() => _error = 'Error al cargar configuracion');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _error = null);
    try {
      await context.read<NotificationService>().toggleEnabled(value);
    } catch (e) {
      setState(() => _error = 'Error al actualizar configuracion');
    }
  }

  Future<void> _setThreshold(int value) async {
    setState(() => _error = null);
    try {
      await context.read<NotificationService>().setPriceChangeThreshold(value);
    } catch (e) {
      setState(() => _error = 'Error al actualizar umbral');
    }
  }

  Future<void> _requestPermission() async {
    final notificationService = context.read<NotificationService>();

    // Show the permission bottom sheet
    final accepted = await NotificationPermissionSheet.show(context);

    if (accepted) {
      // User accepted, request native permission
      final granted = await notificationService.requestPermissionAndSetup();
      if (granted) {
        await notificationService.registerTokenAfterLogin();
      }
    }
  }

  void _showThresholdPicker() {
    final notificationService = context.read<NotificationService>();
    final currentThreshold = notificationService.priceChangeThreshold;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ThresholdPicker(
        currentValue: currentThreshold,
        onSelected: (value) {
          Navigator.pop(context);
          _setThreshold(value);
        },
      ),
    );
  }

  void _showQuietHoursPicker() {
    final notificationService = context.read<NotificationService>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _QuietHoursPicker(
        startTime: notificationService.quietHoursStart,
        endTime: notificationService.quietHoursEnd,
        onSaved: (start, end) async {
          Navigator.pop(context);
          try {
            await notificationService.setQuietHours(start, end);
          } catch (e) {
            if (mounted) {
              setState(() => _error = 'Error al configurar horas de silencio');
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = context.watch<NotificationService>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgElevated,
        title: const Text('Notificaciones'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Permission status
                if (!notificationService.hasPermission) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notifications_off_rounded, color: AppColors.warning),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Notificaciones desactivadas',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Activa las notificaciones para recibir alertas de cambios de precio en tus activos favoritos.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _requestPermission,
                            icon: const Icon(Icons.notifications_active_rounded, size: 18),
                            label: const Text('Activar notificaciones'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: AppColors.bgPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Error message
                if (_error != null) ...[
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
                            _error!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Main toggle
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      title: 'Alertas de precio',
                      subtitle: 'Recibe notificaciones cuando tus activos favoritos cambien significativamente',
                      trailing: Switch.adaptive(
                        value: notificationService.enabled,
                        onChanged: notificationService.hasPermission ? _toggleEnabled : null,
                        activeColor: AppColors.brandAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Settings (only show when enabled)
                if (notificationService.enabled) ...[
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.trending_up,
                        title: 'Umbral de cambio',
                        subtitle: 'Alertar cuando el precio cambie mas de',
                        trailing: GestureDetector(
                          onTap: _showThresholdPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.bgTertiary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${notificationService.priceChangeThreshold}%',
                                  style: const TextStyle(
                                    color: AppColors.brandAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.do_not_disturb_on_outlined,
                        title: 'Horas de silencio',
                        subtitle: _getQuietHoursSubtitle(notificationService),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: _showQuietHoursPicker,
                        ),
                        onTap: _showQuietHoursPicker,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Info text
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
                            Icon(
                              Icons.info_outline,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Como funcionan las alertas',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Recibiras una notificacion cuando un activo en tus favoritos cambie de precio mas del umbral configurado. Para evitar spam, hay un periodo de espera de 60 minutos entre alertas del mismo activo.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Debug: FCM Token
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgTertiary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.bug_report,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Debug: FCM Token',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (notificationService.fcmToken != null)
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              color: AppColors.brandAccent,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                  text: notificationService.fcmToken!,
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Token copiado'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        notificationService.fcmToken ?? 'No token disponible',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Permiso: ${notificationService.hasPermission ? "Sí" : "No"} | '
                        'Inicializado: ${notificationService.isInitialized ? "Sí" : "No"}',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _getQuietHoursSubtitle(NotificationService service) {
    if (service.quietHoursStart == null || service.quietHoursEnd == null) {
      return 'No configuradas';
    }
    return '${service.quietHoursStart} - ${service.quietHoursEnd}';
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgTertiary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.brandAccent, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ThresholdPicker extends StatelessWidget {
  final int currentValue;
  final ValueChanged<int> onSelected;

  const _ThresholdPicker({
    required this.currentValue,
    required this.onSelected,
  });

  static const thresholds = [1, 2, 3, 5, 7, 10, 15, 20, 25, 30];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Umbral de cambio de precio',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Alertar cuando el precio cambie mas de',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: thresholds.length,
              itemBuilder: (context, index) {
                final threshold = thresholds[index];
                final isSelected = threshold == currentValue;
                return ListTile(
                  title: Text(
                    '$threshold%',
                    style: TextStyle(
                      color: isSelected ? AppColors.brandAccent : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.brandAccent)
                      : null,
                  onTap: () => onSelected(threshold),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _QuietHoursPicker extends StatefulWidget {
  final String? startTime;
  final String? endTime;
  final Function(String?, String?) onSaved;

  const _QuietHoursPicker({
    this.startTime,
    this.endTime,
    required this.onSaved,
  });

  @override
  State<_QuietHoursPicker> createState() => _QuietHoursPickerState();
}

class _QuietHoursPickerState extends State<_QuietHoursPicker> {
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _startTime = _parseTime(widget.startTime);
    _endTime = _parseTime(widget.endTime);
    _enabled = _startTime != null && _endTime != null;
  }

  TimeOfDay? _parseTime(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 22, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 7, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.brandAccent,
              surface: AppColors.bgSecondary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Horas de silencio',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'No enviar notificaciones durante este horario',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Enable toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Activar horas de silencio',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  Switch.adaptive(
                    value: _enabled,
                    onChanged: (value) {
                      setState(() {
                        _enabled = value;
                        if (value) {
                          _startTime ??= const TimeOfDay(hour: 22, minute: 0);
                          _endTime ??= const TimeOfDay(hour: 7, minute: 0);
                        }
                      });
                    },
                    activeColor: AppColors.brandAccent,
                  ),
                ],
              ),
            ),

            if (_enabled) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _TimeButton(
                        label: 'Desde',
                        time: _startTime != null ? _formatTime(_startTime!) : '--:--',
                        onTap: () => _pickTime(true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _TimeButton(
                        label: 'Hasta',
                        time: _endTime != null ? _formatTime(_endTime!) : '--:--',
                        onTap: () => _pickTime(false),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Save button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_enabled && _startTime != null && _endTime != null) {
                      widget.onSaved(_formatTime(_startTime!), _formatTime(_endTime!));
                    } else {
                      widget.onSaved(null, null);
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgTertiary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
