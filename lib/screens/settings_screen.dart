import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vpn_provider.dart';
import '../config/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            _buildSectionHeader(context, 'Appearance'),
            const SizedBox(height: 12),
            _buildSettingsCard(
              context,
              isDark: isDark,
              children: [
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return _buildSwitchTile(
                      context,
                      icon: Icons.dark_mode_rounded,
                      iconColor: AppColors.darkAccent,
                      title: 'Dark Mode',
                      subtitle: 'Use dark theme',
                      value: themeProvider.isDarkMode,
                      onChanged: (value) => themeProvider.toggleTheme(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Connection Section
            _buildSectionHeader(context, 'Connection'),
            const SizedBox(height: 12),
            _buildSettingsCard(
              context,
              isDark: isDark,
              children: [
                Consumer<VpnProvider>(
                  builder: (context, vpn, child) {
                    return _buildSwitchTile(
                      context,
                      icon: Icons.play_circle_outline_rounded,
                      iconColor: AppColors.connected,
                      title: 'Auto-Connect',
                      subtitle: 'Connect on app startup',
                      value: vpn.autoConnect,
                      onChanged: (value) => vpn.setAutoConnect(value),
                    );
                  },
                ),
                const Divider(height: 1),
                Consumer<VpnProvider>(
                  builder: (context, vpn, child) {
                    return _buildSwitchTile(
                      context,
                      icon: Icons.security_rounded,
                      iconColor: AppColors.disconnected,
                      title: 'Kill Switch',
                      subtitle: 'Block internet if VPN disconnects',
                      value: vpn.killSwitch,
                      onChanged: (value) => vpn.setKillSwitch(value),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // About Section
            _buildSectionHeader(context, 'About'),
            const SizedBox(height: 12),
            _buildSettingsCard(
              context,
              isDark: isDark,
              children: [
                _buildInfoTile(
                  context,
                  icon: Icons.info_outline_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: 'Version',
                  value: '1.0.0',
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  context,
                  icon: Icons.code_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: 'Build',
                  value: '2026.01.14',
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Footer
            Center(
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
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
                  const SizedBox(height: 12),
                  Text(
                    'Chakra VPN',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Secure. Private. Fast.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}
