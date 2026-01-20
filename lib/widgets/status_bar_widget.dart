import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vpn_provider.dart';
import '../config/app_colors.dart';

class StatusBarWidget extends StatelessWidget {
  const StatusBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnProvider>(
      builder: (context, vpn, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.glassWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Connection Status Row
                  Row(
                    children: [
                      // Status indicator dot
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getStatusColor(vpn.connectionState),
                          shape: BoxShape.circle,
                          boxShadow:
                              vpn.isConnected
                                  ? [
                                    BoxShadow(
                                      color: AppColors.accent.withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        vpn.statusText,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(vpn.connectionState),
                        ),
                      ),
                      const Spacer(),
                      if (vpn.isConnected)
                        Text(
                          vpn.currentIp,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),

                  // Speed Gauges (only when connected)
                  if (vpn.isConnected) ...[
                    const SizedBox(height: 20),
                    Container(height: 1, color: AppColors.glassBorder),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        // Upload
                        Expanded(
                          child: _buildSpeedGauge(
                            icon: Icons.arrow_upward_rounded,
                            label: 'Upload',
                            value: vpn.formattedUploadSpeed,
                          ),
                        ),
                        // Divider
                        Container(
                          width: 1,
                          height: 50,
                          color: AppColors.glassBorder,
                        ),
                        // Download
                        Expanded(
                          child: _buildSpeedGauge(
                            icon: Icons.arrow_downward_rounded,
                            label: 'Download',
                            value: vpn.formattedDownloadSpeed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeedGauge({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

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
      case VpnConnectionState.error:
        return AppColors.error;
    }
  }
}
