import 'dart:async';
import 'package:flutter/services.dart';

/// Platform channel service for VPN communication
/// Handles all native VPN operations (Android VpnService, iOS Network Extension)
class VpnPlatformService {
  static const MethodChannel _channel = MethodChannel('com.example.chakra/vpn');
  static const EventChannel _statusChannel = EventChannel('com.example.chakra/vpn_status');

  StreamSubscription<dynamic>? _statusSubscription;
  Function(Map<String, dynamic>)? _onStatusUpdate;

  /// Initialize VPN service and set up status stream
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
      _statusSubscription = _statusChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (_onStatusUpdate != null && event is Map) {
            _onStatusUpdate!(Map<String, dynamic>.from(event));
          }
        },
        onError: (error) {
          print('VPN status stream error: $error');
        },
      );
    } catch (e) {
      print('Failed to initialize VPN service: $e');
      rethrow;
    }
  }

  /// Set callback for status updates
  void setStatusCallback(Function(Map<String, dynamic>) callback) {
    _onStatusUpdate = callback;
  }

  /// Generate or retrieve WireGuard keypair
  /// Returns: {privateKey: String, publicKey: String, ipAddress: String}
  Future<Map<String, String>> getOrCreateKeypair() async {
    try {
      final result = await _channel.invokeMethod('getOrCreateKeypair');
      return Map<String, String>.from(result);
    } catch (e) {
      print('Failed to get/create keypair: $e');
      rethrow;
    }
  }

  /// Connect VPN
  /// Requires: endpoint (public IP or DDNS hostname), clientPrivateKey, clientPublicKey,
  /// clientIpAddress, and allowedIps (e.g. '0.0.0.0/0' for full tunnel)
  Future<bool> connect({
    required String endpoint,
    required String clientPrivateKey,
    required String clientPublicKey,
    required String clientIpAddress,
    required String allowedIps,
  }) async {
    try {
      final result = await _channel.invokeMethod('connect', {
        'endpoint': endpoint,
        'clientPrivateKey': clientPrivateKey,
        'clientPublicKey': clientPublicKey,
        'clientIpAddress': clientIpAddress,
        'allowedIps': allowedIps,
        // NO DNS - let OS handle DNS resolution
      });
      return result as bool;
    } catch (e) {
      print('Failed to connect VPN: $e');
      return false;
    }
  }

  /// Disconnect VPN
  Future<bool> disconnect() async {
    try {
      final result = await _channel.invokeMethod('disconnect');
      return result as bool;
    } catch (e) {
      print('Failed to disconnect VPN: $e');
      return false;
    }
  }

  /// Get current VPN status
  /// Returns: {status: String, publicIp: String?, latency: int?, bytesSent: int?, bytesReceived: int?, uptime: int?}
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _channel.invokeMethod('getStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Failed to get VPN status: $e');
      return {
        'status': 'disconnected',
        'publicIp': null,
        'latency': null,
        'bytesSent': null,
        'bytesReceived': null,
        'uptime': null,
      };
    }
  }

  /// Request VPN permission (Android only, iOS handled automatically)
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod('requestPermission');
      return result as bool;
    } catch (e) {
      print('Failed to request VPN permission: $e');
      return false;
    }
  }

  /// Enable / disable kill switch behavior (forwarded to native layer)
  Future<void> setKillSwitchEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setKillSwitchEnabled', {
        'enabled': enabled,
      });
    } catch (e) {
      print('Failed to set kill switch: $e');
    }
  }

  /// Cleanup
  void dispose() {
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _onStatusUpdate = null;
  }
}
