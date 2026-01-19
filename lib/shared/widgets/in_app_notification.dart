import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Controller for managing in-app notifications
class InAppNotificationController {
  static final InAppNotificationController _instance = InAppNotificationController._internal();
  factory InAppNotificationController() => _instance;
  InAppNotificationController._internal();

  final _notificationController = StreamController<InAppNotificationData?>.broadcast();
  Stream<InAppNotificationData?> get notificationStream => _notificationController.stream;

  /// Show an in-app notification
  void show({
    required String title,
    required String body,
    String? imageUrl,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    _notificationController.add(InAppNotificationData(
      title: title,
      body: body,
      imageUrl: imageUrl,
      onTap: onTap,
      duration: duration,
    ));
  }

  /// Dismiss the current notification
  void dismiss() {
    _notificationController.add(null);
  }

  void dispose() {
    _notificationController.close();
  }
}

/// Data class for notification content
class InAppNotificationData {
  final String title;
  final String body;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Duration duration;

  InAppNotificationData({
    required this.title,
    required this.body,
    this.imageUrl,
    this.onTap,
    this.duration = const Duration(seconds: 4),
  });
}

/// Widget that listens for and displays in-app notifications
class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;

  const InAppNotificationOverlay({
    super.key,
    required this.child,
  });

  @override
  State<InAppNotificationOverlay> createState() => _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay> {
  final _controller = InAppNotificationController();
  InAppNotificationData? _currentNotification;
  Timer? _dismissTimer;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller.notificationStream.listen(_handleNotification);
  }

  void _handleNotification(InAppNotificationData? data) {
    _dismissTimer?.cancel();

    if (data == null) {
      _hideNotification();
      return;
    }

    setState(() {
      _currentNotification = data;
      _isVisible = true;
    });

    _dismissTimer = Timer(data.duration, _hideNotification);
  }

  void _hideNotification() {
    if (mounted) {
      setState(() {
        _isVisible = false;
      });
    }
  }

  void _onTap() {
    _currentNotification?.onTap?.call();
    _hideNotification();
  }

  void _onDismiss() {
    _hideNotification();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Notification banner
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          top: _isVisible ? MediaQuery.of(context).padding.top + 8 : -150,
          left: 8,
          right: 8,
          child: _currentNotification != null
              ? _IOSStyleNotificationBanner(
                  data: _currentNotification!,
                  onTap: _onTap,
                  onDismiss: _onDismiss,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// iOS-style notification banner widget
class _IOSStyleNotificationBanner extends StatelessWidget {
  final InAppNotificationData data;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _IOSStyleNotificationBanner({
    required this.data,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          onDismiss();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              // Liquid Glass effect - semi-transparent with gradient
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 42,
                    height: 42,
                    color: AppColors.bgPrimary,
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/splash/logo.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'now',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        data.body,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
