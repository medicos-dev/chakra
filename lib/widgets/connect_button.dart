import 'dart:ui';
import 'dart:math' as math;
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
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Subtle pulse for connected state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotation for connecting state
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Glow animation for connected state
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnProvider>(
      builder: (context, vpn, child) {
        final isLoading = vpn.isConnecting || vpn.isReconnecting;
        final isConnected = vpn.isConnected;

        if (isLoading) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer above button
            AnimatedOpacity(
              opacity: isConnected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Text(
                      vpn.connectionDuration,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textPrimary,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main Power Button
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isConnected ? _pulseAnimation.value : 1.0,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: isLoading ? null : () => vpn.toggleConnection(),
                child: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.darkSurfaceElevated,
                        border: Border.all(
                          color:
                              isConnected
                                  ? AppColors.accent.withOpacity(0.5)
                                  : AppColors.glassBorder,
                          width: 2,
                        ),
                        boxShadow: [
                          // Outer glow for connected state
                          if (isConnected)
                            BoxShadow(
                              color: AppColors.accent.withOpacity(
                                _glowAnimation.value * 0.4,
                              ),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          // Subtle ambient shadow
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.1),
                                  Colors.white.withOpacity(0.02),
                                ],
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Loading ring
                                if (isLoading)
                                  AnimatedBuilder(
                                    animation: _rotationController,
                                    builder: (context, child) {
                                      return Transform.rotate(
                                        angle:
                                            _rotationController.value *
                                            2 *
                                            math.pi,
                                        child: SizedBox(
                                          width: 160,
                                          height: 160,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.connecting
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                // Power Icon
                                Icon(
                                  Icons.power_settings_new_rounded,
                                  size: 72,
                                  color:
                                      isConnected
                                          ? AppColors.accent
                                          : isLoading
                                          ? AppColors.connecting
                                          : AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Status Text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _getStatusText(vpn.connectionState),
                key: ValueKey(vpn.connectionState),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              _getSubtitle(vpn.connectionState),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        );
      },
    );
  }

  String _getStatusText(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.disconnected:
        return 'Not Connected';
      case VpnConnectionState.connecting:
        return 'Connecting...';
      case VpnConnectionState.connected:
        return 'Protected';
      case VpnConnectionState.reconnecting:
        return 'Reconnecting...';
      case VpnConnectionState.error:
        return 'Connection Failed';
    }
  }

  String _getSubtitle(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.disconnected:
        return 'Tap to connect';
      case VpnConnectionState.connecting:
        return 'Establishing secure tunnel';
      case VpnConnectionState.connected:
        return 'Your connection is secure';
      case VpnConnectionState.reconnecting:
        return 'Please wait...';
      case VpnConnectionState.error:
        return 'Tap to retry';
    }
  }
}
