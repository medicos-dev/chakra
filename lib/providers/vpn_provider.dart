import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/vpn_platform_service.dart';
import '../utils/ip_selector.dart';
import 'dart:async';
import 'dart:math';

enum VpnConnectionState { disconnected, connecting, connected, reconnecting, error }

/// VPN Provider with real native VPN integration
/// Handles state persistence, auto-reconnect, and background operation
class VpnProvider extends ChangeNotifier {
  final VpnPlatformService _vpnService = VpnPlatformService();
  
  VpnConnectionState _connectionState = VpnConnectionState.disconnected;
  String _currentIp = '---';
  int _latency = 0;
  int _uploadBytes = 0;
  int _downloadBytes = 0;
  DateTime? _connectedSince;
  bool _autoConnect = false;
  bool _killSwitch = false;
  String? _errorMessage;
  Timer? _statusPollTimer;
  bool _isInitialized = false;
  bool _reconnectInProgress = false;
  DateTime? _lastReconnectAttempt;
  static const Duration _minReconnectDelay = Duration(seconds: 5);
  static const Duration _maxReconnectWindow = Duration(minutes: 5);

  // Server configuration (single server model)
  static const String serverPublicKey = 'YFjlqgULP4hKxYHGM1e/MtzVfuzBMjSysPxSGUnn6lc=';
  static const String defaultServerEndpoint = 'chakravpn.duckdns.org:51820'; // Default endpoint
  
  String _serverEndpoint = defaultServerEndpoint;
  static const int _maxIpRetries = 8; // Maximum IP retry attempts

  // Getters
  VpnConnectionState get connectionState => _connectionState;
  String get currentIp => _currentIp;
  int get latency => _latency;
  int get uploadBytes => _uploadBytes;
  int get downloadBytes => _downloadBytes;
  DateTime? get connectedSince => _connectedSince;
  bool get autoConnect => _autoConnect;
  bool get killSwitch => _killSwitch;
  String? get errorMessage => _errorMessage;
  String get serverEndpoint => _serverEndpoint;

  bool get isConnected => _connectionState == VpnConnectionState.connected;
  bool get isConnecting => _connectionState == VpnConnectionState.connecting;
  bool get isDisconnected =>
      _connectionState == VpnConnectionState.disconnected;
  bool get isReconnecting =>
      _connectionState == VpnConnectionState.reconnecting;
  bool get isError => _connectionState == VpnConnectionState.error;

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
      case VpnConnectionState.error:
        return 'Error';
    }
  }

  VpnProvider() {
    _initialize();
  }

  /// Initialize VPN service and restore state
  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadSettings();
      
      // Set up status callback
      _vpnService.setStatusCallback(_onStatusUpdate);
      
      // Initialize platform service
      await _vpnService.initialize();
      
      // Restore VPN state on app start
      await _restoreVpnState();
      
      // Start periodic status polling
      _startStatusPolling();
      
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize VPN provider: $e');
      _errorMessage = 'Initialization failed: $e';
      _connectionState = VpnConnectionState.error;
      notifyListeners();
    }
  }

  /// Restore VPN state from persistence
  /// Checks user intent (shouldBeConnected) and actual VPN status
  Future<void> _restoreVpnState() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldBeConnected = prefs.getBool('should_be_connected') ?? false;
    
    if (!shouldBeConnected) {
      // User didn't want VPN connected, ensure it's disconnected
      final status = await _vpnService.getStatus();
      if (status['status'] != 'disconnected') {
        await _vpnService.disconnect();
      }
      _updateStateFromStatus(status);
      return;
    }
    
    // User wanted VPN connected, check actual status
    final status = await _vpnService.getStatus();
    final actualStatus = status['status'] as String?;
    
    if (actualStatus == 'connected') {
      // VPN is up, restore UI state
      _updateStateFromStatus(status);
    } else if (actualStatus == 'disconnected' || actualStatus == null) {
      // VPN is down but user wants it connected -> auto-reconnect
      _connectionState = VpnConnectionState.reconnecting;
      notifyListeners();
      await connect();
    } else {
      // Other states (connecting, reconnecting, error)
      _updateStateFromStatus(status);
    }
  }

  /// Handle status updates from native side
  void _onStatusUpdate(Map<String, dynamic> status) {
    _updateStateFromStatus(status);
  }

  /// Update internal state from native status
  void _updateStateFromStatus(Map<String, dynamic> status) {
    final statusStr = status['status'] as String? ?? 'disconnected';
    
    switch (statusStr) {
      case 'connected':
        _connectionState = VpnConnectionState.connected;
        _currentIp = status['publicIp'] as String? ?? '---';
        _latency = status['latency'] as int? ?? 0;
        _uploadBytes = status['bytesSent'] as int? ?? 0;
        _downloadBytes = status['bytesReceived'] as int? ?? 0;
        final uptimeSeconds = status['uptime'] as int? ?? 0;
        if (_connectedSince == null && uptimeSeconds > 0) {
          _connectedSince = DateTime.now().subtract(Duration(seconds: uptimeSeconds));
        }
        _errorMessage = null;
        break;
      case 'connecting':
        _connectionState = VpnConnectionState.connecting;
        break;
      case 'reconnecting':
        _connectionState = VpnConnectionState.reconnecting;
        break;
      case 'disconnected':
        _connectionState = VpnConnectionState.disconnected;
        _currentIp = '---';
        _latency = 0;
        _connectedSince = null;
        _uploadBytes = 0;
        _downloadBytes = 0;
        _errorMessage = null;
        break;
      case 'error':
        _connectionState = VpnConnectionState.error;
        _errorMessage = status['errorMessage'] as String? ?? 'Unknown error';
        break;
    }
    
    notifyListeners();
  }

  /// Start periodic status polling (fallback if event stream fails)
  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_connectionState == VpnConnectionState.connected ||
          _connectionState == VpnConnectionState.reconnecting ||
          _connectionState == VpnConnectionState.connecting) {
        try {
          final status = await _vpnService.getStatus();
          _updateStateFromStatus(status);
        } catch (e) {
          print('Status polling error: $e');
        }
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoConnect = prefs.getBool('auto_connect') ?? false;
    _killSwitch = prefs.getBool('kill_switch') ?? false;
    _serverEndpoint = prefs.getString('server_endpoint') ?? defaultServerEndpoint;
    
    // Restore kill switch state to native layer
    await _vpnService.setKillSwitchEnabled(_killSwitch);
    
    notifyListeners();
  }

  /// Connect VPN
  /// Generates/retrieves keypair, saves user intent, and starts VPN tunnel
  Future<void> connect() async {
    if (_connectionState == VpnConnectionState.connected) return;
    if (_connectionState == VpnConnectionState.connecting) return;
    
    // Prevent reconnect storms: check if reconnect is in progress or too soon since last attempt
    if (_reconnectInProgress) {
      print('Reconnect already in progress, skipping');
      return;
    }
    
    final now = DateTime.now();
    if (_lastReconnectAttempt != null) {
      final timeSinceLastAttempt = now.difference(_lastReconnectAttempt!);
      if (timeSinceLastAttempt < _minReconnectDelay) {
        print('Reconnect throttled: ${timeSinceLastAttempt.inSeconds}s since last attempt (min: ${_minReconnectDelay.inSeconds}s)');
        return;
      }
      
      // Reset if we're outside the max window (allows fresh attempts after extended period)
      if (timeSinceLastAttempt > _maxReconnectWindow) {
        _lastReconnectAttempt = null;
      }
    }

    _reconnectInProgress = true;
    _lastReconnectAttempt = DateTime.now();
    
    try {
      // Request permission (Android)
      final hasPermission = await _vpnService.requestPermission();
      if (!hasPermission) {
        _connectionState = VpnConnectionState.error;
        _errorMessage = 'VPN permission denied';
        _reconnectInProgress = false;
        notifyListeners();
        return;
      }

      _connectionState = VpnConnectionState.connecting;
      notifyListeners();

      // Get or create WireGuard keypair
      final keypair = await _vpnService.getOrCreateKeypair();
      final clientPrivateKey = keypair['privateKey']!;
      final clientPublicKey = keypair['publicKey']!;

      // Save user intent: user wants VPN connected
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('should_be_connected', true);

      // Automatic IP assignment with collision detection
      String? assignedIp;
      String currentCandidateIp = await IpSelector.getInitialCandidateIp();
      bool connectionSuccess = false;
      
      // Add small random delay to reduce simultaneous collisions
      final random = Random();
      await Future.delayed(Duration(milliseconds: random.nextInt(500)));
      
      for (int attempt = 0; attempt < _maxIpRetries; attempt++) {
        try {
          print('Attempting connection with IP: $currentCandidateIp (attempt ${attempt + 1}/$_maxIpRetries)');
          
          // Attempt connection with current candidate IP
          final success = await _vpnService.connect(
            endpoint: _serverEndpoint,
            clientPrivateKey: clientPrivateKey,
            clientPublicKey: clientPublicKey,
            clientIpAddress: currentCandidateIp,
            allowedIps: '0.0.0.0/0', // Full tunnel: route all traffic through VPN
          );
          
          if (success) {
            // Connection successful - save this IP
            assignedIp = currentCandidateIp;
            await IpSelector.saveAssignedIp(currentCandidateIp);
            connectionSuccess = true;
            print('Successfully connected with IP: $currentCandidateIp');
            break;
          } else {
            // Connection failed - try next IP (treat as potential collision)
            print('Connection failed with IP $currentCandidateIp, trying next candidate');
            currentCandidateIp = await IpSelector.getNextCandidateIp(
              currentCandidateIp,
              randomize: attempt == 0, // Randomize on first retry to reduce collisions
            );
            
            // Small delay before next attempt
            await Future.delayed(Duration(milliseconds: 300 + random.nextInt(200)));
          }
        } catch (e) {
          // Connection error - try next IP
          print('Connection error with IP $currentCandidateIp: $e, trying next candidate');
          currentCandidateIp = await IpSelector.getNextCandidateIp(
            currentCandidateIp,
            randomize: attempt == 0,
          );
          
          await Future.delayed(Duration(milliseconds: 300 + random.nextInt(200)));
        }
      }

      if (connectionSuccess && assignedIp != null) {
        // Status will be updated via event stream
        _connectedSince = DateTime.now();
        _reconnectInProgress = false;
      } else {
        _connectionState = VpnConnectionState.error;
        _errorMessage = 'Failed to connect: No available IP found after $_maxIpRetries attempts';
        await prefs.setBool('should_be_connected', false);
        _reconnectInProgress = false;
        notifyListeners();
      }
    } catch (e) {
      _connectionState = VpnConnectionState.error;
      _errorMessage = 'Connection error: $e';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('should_be_connected', false);
      _reconnectInProgress = false;
      notifyListeners();
    }
  }

  /// Disconnect VPN
  /// Saves user intent and stops VPN tunnel
  Future<void> disconnect() async {
    if (_connectionState == VpnConnectionState.disconnected) return;

    try {
      // Save user intent: user wants VPN disconnected
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('should_be_connected', false);

      final success = await _vpnService.disconnect();
      
      if (success) {
        _connectionState = VpnConnectionState.disconnected;
        _currentIp = '---';
        _latency = 0;
        _connectedSince = null;
        _uploadBytes = 0;
        _downloadBytes = 0;
        _errorMessage = null;
        notifyListeners();
      } else {
        _connectionState = VpnConnectionState.error;
        _errorMessage = 'Failed to disconnect';
        notifyListeners();
      }
    } catch (e) {
      _connectionState = VpnConnectionState.error;
      _errorMessage = 'Disconnect error: $e';
      notifyListeners();
    }
  }

  Future<void> toggleConnection() async {
    if (_connectionState == VpnConnectionState.connected ||
        _connectionState == VpnConnectionState.reconnecting) {
      await disconnect();
    } else if (_connectionState == VpnConnectionState.disconnected ||
               _connectionState == VpnConnectionState.error) {
      await connect();
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
    
    // Notify native layer about kill switch state
    await _vpnService.setKillSwitchEnabled(value);
    
    notifyListeners();
  }

  Future<void> setServerEndpoint(String endpoint) async {
    _serverEndpoint = endpoint;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_endpoint', endpoint);
    notifyListeners();
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _vpnService.dispose();
    super.dispose();
  }
}
