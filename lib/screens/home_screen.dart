import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import '../widgets/connect_button.dart';
import '../widgets/status_bar_widget.dart';
import '../widgets/reconnection_overlay.dart';
import '../config/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.darkBackground,
                        AppColors.darkSurface.withValues(alpha: 0.3),
                      ]
                    : [
                        AppColors.lightBackground,
                        AppColors.lightSurface.withValues(alpha: 0.5),
                      ],
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // App Bar with improved styling
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                  child: Row(
                    children: [
                      // Logo with subtle shadow
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // App name with better typography
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chakra VPN',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Secure. Private. Fast.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Settings button with improved styling
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/settings');
                          },
                          icon: const Icon(Icons.settings_rounded),
                          iconSize: 22,
                          padding: const EdgeInsets.all(10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Spacer(flex: 2),
                // Connect Button with better spacing
                const ConnectButton(),
                const Spacer(flex: 2),
                // Status Bar with improved spacing
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const StatusBarWidget(),
                ),
                const SizedBox(height: 32),
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
