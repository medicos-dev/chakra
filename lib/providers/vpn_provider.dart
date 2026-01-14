import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VpnConnectionState { disconnected, connecting, connected, reconnecting }

class VpnProvider extends ChangeNotifier {
  VpnConnectionState _connectionState = VpnConnectionState.disconnected;
  String _currentIp = '---';
  int _latency = 0;
  int _uploadBytes = 0;
  int _downloadBytes = 0;
  DateTime? _connectedSince;
  bool _autoConnect = false;
  bool _killSwitch = false;

  // Getters
  VpnConnectionState get connectionState => _connectionState;
  String get currentIp => _currentIp;
  int get latency => _latency;
  int get uploadBytes => _uploadBytes;
  int get downloadBytes => _downloadBytes;
  DateTime? get connectedSince => _connectedSince;
  bool get autoConnect => _autoConnect;
  bool get killSwitch => _killSwitch;

  bool get isConnected => _connectionState == VpnConnectionState.connected;
  bool get isConnecting => _connectionState == VpnConnectionState.connecting;
  bool get isDisconnected =>
      _connectionState == VpnConnectionState.disconnected;
  bool get isReconnecting =>
      _connectionState == VpnConnectionState.reconnecting;

  String get connectionDuration {
    if (_connectedSince == null) return '00:00:00';
    final duration = DateTime.now().difference(_connectedSince!);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String get formattedUpload {
    if (_uploadBytes < 1024) return '$_uploadBytes B';
    if (_uploadBytes < 1024 * 1024)
      return '${(_uploadBytes / 1024).toStringAsFixed(1)} KB';
    if (_uploadBytes < 1024 * 1024 * 1024)
      return '${(_uploadBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(_uploadBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedDownload {
    if (_downloadBytes < 1024) return '$_downloadBytes B';
    if (_downloadBytes < 1024 * 1024)
      return '${(_downloadBytes / 1024).toStringAsFixed(1)} KB';
    if (_downloadBytes < 1024 * 1024 * 1024)
      return '${(_downloadBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(_downloadBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get statusText {
    switch (_connectionState) {
      case VpnConnectionState.disconnected:
        return 'Not Protected';
      case VpnConnectionState.connecting:
        return 'Connecting...';
      case VpnConnectionState.connected:
        return 'Protected';
      case VpnConnectionState.reconnecting:
        return 'Reconnecting...';
    }
  }

  VpnProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoConnect = prefs.getBool('auto_connect') ?? false;
    _killSwitch = prefs.getBool('kill_switch') ?? false;
    notifyListeners();
  }

  Future<void> connect() async {
    if (_connectionState == VpnConnectionState.connected) return;

    _connectionState = VpnConnectionState.connecting;
    notifyListeners();

    // Simulate connection delay
    await Future.delayed(const Duration(seconds: 2));

    // Simulate successful connection
    _connectionState = VpnConnectionState.connected;
    _currentIp = '192.168.1.1'; // Home VPN IP
    _latency = 12 + (DateTime.now().millisecond % 20);
    _connectedSince = DateTime.now();
    _uploadBytes = 0;
    _downloadBytes = 0;

    notifyListeners();
    _startDataSimulation();
  }

  Future<void> disconnect() async {
    _connectionState = VpnConnectionState.disconnected;
    _currentIp = '---';
    _latency = 0;
    _connectedSince = null;
    notifyListeners();
  }

  Future<void> toggleConnection() async {
    if (_connectionState == VpnConnectionState.connected) {
      await disconnect();
    } else if (_connectionState == VpnConnectionState.disconnected) {
      await connect();
    }
  }

  void simulateReconnection() async {
    _connectionState = VpnConnectionState.reconnecting;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 3));

    _connectionState = VpnConnectionState.connected;
    _latency = 15 + (DateTime.now().millisecond % 25);
    notifyListeners();
  }

  void _startDataSimulation() async {
    while (_connectionState == VpnConnectionState.connected) {
      await Future.delayed(const Duration(seconds: 1));
      if (_connectionState == VpnConnectionState.connected) {
        _uploadBytes += 1024 + (DateTime.now().millisecond * 10);
        _downloadBytes += 2048 + (DateTime.now().millisecond * 20);
        _latency = 10 + (DateTime.now().millisecond % 30);
        notifyListeners();
      }
    }
  }

  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_connect', value);
    notifyListeners();
  }

  Future<void> setKillSwitch(bool value) async {
    _killSwitch = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kill_switch', value);
    notifyListeners();
  }
}
