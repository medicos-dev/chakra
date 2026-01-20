import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../providers/vpn_provider.dart';
import '../widgets/connect_button.dart';
import '../widgets/status_bar_widget.dart';
import '../widgets/reconnection_overlay.dart';
import '../config/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine light/dark mode for styling
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Dynamic Background Gradient
          Consumer<VpnProvider>(
            builder: (context, vpn, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5,
                    colors:
                        vpn.isConnected
                            ? [
                              AppColors.accent.withOpacity(
                                isDark ? 0.15 : 0.05,
                              ),
                              isDark
                                  ? AppColors.darkBackground
                                  : AppColors.lightBackground,
                            ]
                            : [
                              (isDark
                                      ? AppColors.darkSurface
                                      : Colors.grey.shade200)
                                  .withOpacity(0.5),
                              isDark
                                  ? AppColors.darkBackground
                                  : AppColors.lightBackground,
                            ],
                  ),
                ),
              );
            },
          ),

          // Lottie Overlay for connecting state (Optional: can add specific lottie asset here)
          Consumer<VpnProvider>(
            builder: (context, vpn, child) {
              if (vpn.isConnecting || vpn.isReconnecting) {
                // Placeholder for a connecting animation if desired behind everything
                // keeping it clean for now
                return const SizedBox.shrink();
              }
              return const SizedBox.shrink();
            },
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Glassmorphic App Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isDark
                                  ? AppColors.glassWhite
                                  : Colors.white.withOpacity(0.6)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                isDark ? AppColors.glassBorder : Colors.black12,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Logo
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // App name
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ay ToTo',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? AppColors.textPrimary
                                            : AppColors.lightText,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'Premium VPN',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDark
                                            ? AppColors.textTertiary
                                            : AppColors.lightTextSecondary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Settings button
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/settings');
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  size: 20,
                                  color:
                                      isDark
                                          ? AppColors.textSecondary
                                          : AppColors.lightText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // Connect Button (includes timer)
                const ConnectButton(),

                const Spacer(flex: 3),

                // Status Bar (iOS Island style)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: const StatusBarWidget(),
                ),
              ],
            ),
          ),

          // Reconnection overlay
          Consumer<VpnProvider>(
            builder: (context, vpn, child) {
              if (vpn.isReconnecting) {
                return const ReconnectionOverlay();
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
