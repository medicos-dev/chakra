import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vpn_provider.dart';
import '../widgets/connect_button.dart';
import '../widgets/status_bar_widget.dart';
import '../widgets/tutorial_overlay.dart';
import '../widgets/reconnection_overlay.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Logo
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
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
                      Text(
                        'Chakra VPN',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Settings button
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/settings');
                        },
                        icon: const Icon(Icons.settings_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Connect Button
                const ConnectButton(),
                const Spacer(),
                // Status Bar
                const StatusBarWidget(),
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
          // Tutorial overlay
          if (themeProvider.isFirstLaunch)
            TutorialOverlay(
              onDismiss: () => themeProvider.dismissFirstLaunch(),
            ),
        ],
      ),
    );
  }
}
