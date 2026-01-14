import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import '../config/app_colors.dart';

class StatusBarWidget extends StatelessWidget {
  const StatusBarWidget({super.key});

  Color _getStatusColor(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.disconnected:
        return AppColors.disconnected;
      case VpnConnectionState.connecting:
        return AppColors.connecting;
      case VpnConnectionState.connected:
        return AppColors.connected;
      case VpnConnectionState.reconnecting:
        return AppColors.reconnecting;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<VpnProvider>(
      builder: (context, vpn, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Connection Status Row
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getStatusColor(vpn.connectionState),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(
                            vpn.connectionState,
                          ).withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    vpn.statusText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(vpn.connectionState),
                    ),
                  ),
                  const Spacer(),
                  if (vpn.isConnected)
                    Text(
                      vpn.connectionDuration,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                    ),
                ],
              ),
              if (vpn.isConnected) ...[
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
                // Stats Grid
                Row(
                  children: [
                    _buildStatItem(
                      context,
                      icon: Icons.public_rounded,
                      label: 'IP Address',
                      value: vpn.currentIp,
                    ),
                    _buildStatItem(
                      context,
                      icon: Icons.speed_rounded,
                      label: 'Latency',
                      value: '${vpn.latency} ms',
                      valueColor:
                          vpn.latency < 50
                              ? AppColors.connected
                              : vpn.latency < 100
                              ? AppColors.connecting
                              : AppColors.disconnected,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatItem(
                      context,
                      icon: Icons.arrow_upward_rounded,
                      label: 'Upload',
                      value: vpn.formattedUpload,
                    ),
                    _buildStatItem(
                      context,
                      icon: Icons.arrow_downward_rounded,
                      label: 'Download',
                      value: vpn.formattedDownload,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
