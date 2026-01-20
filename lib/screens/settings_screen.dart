import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vpn_provider.dart';
import '../config/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine if we are effectively in dark mode for styling
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimary : AppColors.lightText,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? AppColors.textPrimary : AppColors.lightText,
            size: 20,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: (isDark ? AppColors.darkSurface : AppColors.lightSurface)
                  .withOpacity(0.7),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
        children: [
          // Appearance Section
          _buildSectionHeader(context, 'Appearance', isDark),
          const SizedBox(height: 16),
          _buildGlassCard(
            context,
            isDark: isDark,
            children: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return Column(
                    children: [
                      _buildThemeSelector(context, themeProvider, isDark),
                    ],
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Connection Section
          _buildSectionHeader(context, 'Connection', isDark),
          const SizedBox(height: 16),
          _buildGlassCard(
            context,
            isDark: isDark,
            children: [
              Consumer<VpnProvider>(
                builder: (context, vpn, child) {
                  return Column(
                    children: [
                      _buildSwitchTile(
                        context,
                        icon: Icons.bolt_rounded,
                        iconColor: AppColors.accent,
                        title: 'Auto-Connect',
                        subtitle: 'Connect automatically on app launch',
                        value: vpn.autoConnect,
                        onChanged: (value) => vpn.setAutoConnect(value),
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildSwitchTile(
                        context,
                        icon: Icons.shield_rounded,
                        iconColor:
                            AppColors.error, // Red for Kill Switch warning feel
                        title: 'Kill Switch',
                        subtitle: 'Block internet when VPN drops',
                        value: vpn.killSwitch,
                        onChanged: (value) => vpn.setKillSwitch(value),
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildActionTile(
                        context,
                        icon: Icons.dns_rounded,
                        iconColor: AppColors.reconnecting, // Blue
                        title: 'Server Endpoint',
                        subtitle: vpn.serverEndpoint,
                        onTap:
                            () =>
                                _showServerEndpointDialog(context, vpn, isDark),
                        isDark: isDark,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 32),

          // About Section
          _buildSectionHeader(context, 'About', isDark),
          const SizedBox(height: 16),
          _buildGlassCard(
            context,
            isDark: isDark,
            children: [
              _buildInfoTile(
                context,
                icon: Icons.info_rounded,
                iconColor: isDark ? Colors.white70 : Colors.black54,
                title: 'Version',
                value: '1.2.0 (Premium)',
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildInfoTile(
                context,
                icon: Icons.code_rounded,
                iconColor: isDark ? Colors.white70 : Colors.black54,
                title: 'Build',
                value: '2026.01.21',
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 48),

          // Footer Logo
          Center(
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ay ToTo VPN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimary : AppColors.lightText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Secure. Private. Limitless.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color:
                        isDark
                            ? AppColors.textTertiary
                            : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textTertiary : AppColors.lightTextSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGlassCard(
    BuildContext context, {
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
      indent: 60,
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
    required bool isDark,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimary : AppColors.lightText,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color:
                isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ),
      activeColor: AppColors.accent,
      activeTrackColor: AppColors.accent.withOpacity(0.3),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimary : AppColors.lightText,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color:
                isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? AppColors.textTertiary : AppColors.lightTextSecondary,
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textPrimary : AppColors.lightText,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color:
              isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Theme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimary : AppColors.lightText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.black.withOpacity(0.3) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildThemeOption(
                  context,
                  title: 'System',
                  mode: ThemeMode.system,
                  currentMode: themeProvider.themeMode,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                  isDark: isDark,
                ),
                _buildThemeOption(
                  context,
                  title: 'Light',
                  mode: ThemeMode.light,
                  currentMode: themeProvider.themeMode,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                  isDark: isDark,
                ),
                _buildThemeOption(
                  context,
                  title: 'Dark',
                  mode: ThemeMode.dark,
                  currentMode: themeProvider.themeMode,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final isSelected = mode == currentMode;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? (isDark ? AppColors.darkSurfaceElevated : Colors.white)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  void _showServerEndpointDialog(
    BuildContext context,
    VpnProvider vpn,
    bool isDark,
  ) {
    final controller = TextEditingController(text: vpn.serverEndpoint);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor:
                isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
            title: Text(
              'Server Endpoint',
              style: TextStyle(
                color: isDark ? AppColors.textPrimary : AppColors.lightText,
              ),
            ),
            content: TextField(
              controller: controller,
              style: TextStyle(
                color: isDark ? AppColors.textPrimary : AppColors.lightText,
              ),
              decoration: InputDecoration(
                labelText: 'Endpoint URL',
                hintText: 'wss://example.com/ws',
                labelStyle: TextStyle(
                  color:
                      isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                ),
                hintStyle: TextStyle(
                  color:
                      isDark
                          ? AppColors.textTertiary
                          : AppColors.lightTextSecondary.withOpacity(0.7),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        isDark
                            ? AppColors.textTertiary
                            : AppColors.lightTextSecondary,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color:
                        isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final endpoint = controller.text.trim();
                  if (endpoint.isNotEmpty) {
                    vpn.setServerEndpoint(endpoint);
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Save',
                  style: TextStyle(color: AppColors.accent),
                ),
              ),
            ],
          ),
    );
  }
}
