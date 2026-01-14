import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import '../config/app_colors.dart';

class ConnectButton extends StatefulWidget {
  const ConnectButton({super.key});

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  LinearGradient _getGradient(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.disconnected:
        return AppColors.connectButtonGradient;
      case VpnConnectionState.connecting:
      case VpnConnectionState.reconnecting:
        return AppColors.connectingButtonGradient;
      case VpnConnectionState.connected:
        return AppColors.disconnectButtonGradient;
    }
  }

  IconData _getIcon(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.disconnected:
        return Icons.power_settings_new_rounded;
      case VpnConnectionState.connecting:
      case VpnConnectionState.reconnecting:
        return Icons.sync_rounded;
      case VpnConnectionState.connected:
        return Icons.shield_rounded;
    }
  }

  String _getButtonText(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.disconnected:
        return 'Connect';
      case VpnConnectionState.connecting:
        return 'Connecting...';
      case VpnConnectionState.connected:
        return 'Disconnect';
      case VpnConnectionState.reconnecting:
        return 'Reconnecting...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnProvider>(
      builder: (context, vpn, child) {
        final isLoading = vpn.isConnecting || vpn.isReconnecting;

        if (isLoading) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main button
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: vpn.isConnected ? _pulseAnimation.value : 1.0,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: isLoading ? null : () => vpn.toggleConnection(),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _getGradient(vpn.connectionState),
                    boxShadow: [
                      BoxShadow(
                        color: _getGradient(
                          vpn.connectionState,
                        ).colors.first.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer ring for connected state
                      if (vpn.isConnected)
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.connected.withValues(alpha: 0.3),
                              width: 3,
                            ),
                          ),
                        ),
                      // Loading ring
                      if (isLoading)
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationController.value * 2 * 3.14159,
                              child: SizedBox(
                                width: 160,
                                height: 160,
                                child: CircularProgressIndicator(
                                  strokeWidth: 4,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            );
                          },
                        ),
                      // Icon
                      AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle:
                                isLoading
                                    ? _rotationController.value * 2 * 3.14159
                                    : 0,
                            child: Icon(
                              _getIcon(vpn.connectionState),
                              size: 64,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Button text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _getButtonText(vpn.connectionState),
                key: ValueKey(vpn.connectionState),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}
