import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

enum VpnConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class VpnProvider extends ChangeNotifier {
  VpnConnectionState _internalConnectionState = VpnConnectionState.disconnected;

  VpnConnectionState get _connectionState => _internalConnectionState;

  set _connectionState(VpnConnectionState state) {
    if (_internalConnectionState == state) return;
    _internalConnectionState = state;
    notifyListeners();

    // Update background notification
    String content = 'Chakra is protecting you';
    if (state == VpnConnectionState.connected) {
      content = 'Protected • $_currentIp';
    } else if (state == VpnConnectionState.connecting) {
      content = 'Connecting...';
    } else if (state == VpnConnectionState.disconnected) {
      content = 'Device not connected';
    }

    print('Updating Notification: $content'); // Debug log

    FlutterBackgroundService().invoke('updateNotification', {
      'title': 'Chakra VPN',
      'content': content,
    });
  }

  String _currentIp = '---';
  int _latency = 0;
  int _uploadBytes = 0;
  int _downloadBytes = 0;
  int _uploadSpeed = 0; // bytes per second
  int _downloadSpeed = 0; // bytes per second
  DateTime? _connectedSince;
  bool _autoConnect = false;
  bool _killSwitch = false;
  String _serverEndpoint = 'wss://chakra-1zg5.onrender.com/ws';

  // Unique Device ID
  late final String _deviceId =
      "Phone_${DateTime.now().millisecondsSinceEpoch}";

  // WebRTC & Platform Channels
  WebSocket? _signalingSocket;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  static const _controlChannel = MethodChannel('com.chakra.vpn/control');
  static const _packetChannel = EventChannel('com.chakra.vpn/packets');
  StreamSubscription? _packetSubscription;
  Timer? _connectionTimeoutTimer;
  Timer? _statsTimer;

  // Stats tracking for speed calculation
  int _lastBytesSent = 0;
  int _lastBytesReceived = 0;

  // Network Connectivity
  StreamSubscription? _connectivitySubscription;

  // Trickle ICE Queue
  final List<RTCIceCandidate> _remoteCandidates = [];
  bool _remoteDescriptionSet = false;

  // Signaling Config
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  // Getters
  VpnConnectionState get connectionState => _connectionState;
  String get currentIp => _currentIp;
  int get latency => _latency;
  int get uploadBytes => _uploadBytes;
  int get downloadBytes => _downloadBytes;
  int get uploadSpeed => _uploadSpeed;
  int get downloadSpeed => _downloadSpeed;
  DateTime? get connectedSince => _connectedSince;
  bool get autoConnect => _autoConnect;
  bool get killSwitch => _killSwitch;
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

  String get formattedUploadSpeed {
    if (_uploadSpeed < 1024) return '$_uploadSpeed B/s';
    if (_uploadSpeed < 1024 * 1024)
      return '${(_uploadSpeed / 1024).toStringAsFixed(1)} KB/s';
    return '${(_uploadSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedDownloadSpeed {
    if (_downloadSpeed < 1024) return '$_downloadSpeed B/s';
    if (_downloadSpeed < 1024 * 1024)
      return '${(_downloadSpeed / 1024).toStringAsFixed(1)} KB/s';
    return '${(_downloadSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
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
        return 'Connection Error';
    }
  }

  VpnProvider() {
    _loadSettings();
    _initConnectivity();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoConnect = prefs.getBool('auto_connect') ?? false;
    _killSwitch = prefs.getBool('kill_switch') ?? false;
    _serverEndpoint =
        prefs.getString('server_endpoint') ??
        'wss://chakra-1zg5.onrender.com/ws';
    notifyListeners();
  }

  /// Initialize network connectivity listener for auto-reconnect
  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      // If connected and network changed, refresh the tunnel
      if (isConnected && results.isNotEmpty) {
        print('Network changed, refreshing tunnel...');
        _refreshConnection();
      }
    });
  }

  /// Refresh connection on network change
  Future<void> _refreshConnection() async {
    await stopConnection();
    await connect();
  }

  Future<void> stopConnection() async {
    // Stop background service notification
    try {
      FlutterBackgroundService().invoke("stopService");
    } catch (e) {
      print('Background service stop error: $e');
    }

    _connectionTimeoutTimer?.cancel();
    _statsTimer?.cancel();
    await _signalingSocket?.close();
    await _dataChannel?.close();
    await _peerConnection?.close();
    _peerConnection = null;
    _dataChannel = null;
    _signalingSocket = null;

    _uploadSpeed = 0;
    _downloadSpeed = 0;
    _lastBytesSent = 0;
    _lastBytesReceived = 0;

    notifyListeners();
  }

  Future<void> connect() async {
    // CRITICAL: Always clean up previous zombies first
    await stopConnection();

    _connectionState = VpnConnectionState.connecting;
    notifyListeners();

    try {
      // 1. Connect to Signaling Server
      String url = _serverEndpoint;
      if (!url.startsWith('ws')) {
        url = 'wss://$url';
      }

      _signalingSocket = await WebSocket.connect(url);
      _signalingSocket?.listen(
        (data) => _handleSignalingMessage(data),
        onDone: () {
          if (_connectionState != VpnConnectionState.disconnected) {
            disconnect();
          }
        },
        onError: (e) {
          print('Signaling Socket Error: $e');
          _setErrorState();
        },
      );

      // 1.5. Start Connection Timeout Timer
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (_connectionState != VpnConnectionState.connected) {
          print('Connection Timeout (15s) - Retrying...');
          disconnect();
          _setErrorState();
        }
      });

      // 2. Create Peer Connection
      _peerConnection = await createPeerConnection(_iceServers, {
        'optional': [],
      });

      _remoteDescriptionSet = false;
      _remoteCandidates.clear();

      _peerConnection?.onIceCandidate = (candidate) {
        // Wait 1 second to ensure the laptop has processed the Offer
        Future.delayed(const Duration(seconds: 1), () {
          _sendSignalingMessage({
            'type': 'candidate',
            'from': _deviceId,
            'to': 'laptop_gateway',
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          });
        });
      };

      _peerConnection?.onConnectionState = (state) {
        if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          disconnect();
        }
      };

      // 3. Create Data Channel
      final dcInit =
          RTCDataChannelInit()
            ..ordered = false
            ..maxRetransmits = 0;

      _dataChannel = await _peerConnection?.createDataChannel('vpn', dcInit);
      _dataChannel?.onDataChannelState = (state) async {
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          print('Data Channel OPEN - Starting VPN Service');
          await _startVpnService();
        } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
          disconnect();
        }
      };

      _dataChannel?.onMessage = (RTCDataChannelMessage message) {
        if (message.isBinary) {
          _downloadBytes += message.binary.length;
          _sendPacketToNative(message.binary);
        }
      };

      // 4. Create Offer
      final offer = await _peerConnection?.createOffer({
        'offerToReceiveVideo': 0,
        'offerToReceiveAudio': 0,
      });
      await _peerConnection?.setLocalDescription(offer!);
      _sendSignalingMessage({
        'type': 'offer',
        'from': _deviceId,
        'to': 'laptop_gateway',
        'sdp': offer?.sdp,
      });
    } catch (e) {
      print('Connection Error: $e');
      _setErrorState();
    }
  }

  void _setErrorState() {
    _connectionState = VpnConnectionState.error;
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      if (_connectionState == VpnConnectionState.error) {
        _connectionState = VpnConnectionState.disconnected;
      }
    });
  }

  Future<void> _startVpnService() async {
    try {
      await _controlChannel.invokeMethod('start');

      _packetSubscription = _packetChannel.receiveBroadcastStream().listen((
        dynamic event,
      ) {
        if (event is List<int>) {
          final bytes = Uint8List.fromList(event);
          _uploadBytes += bytes.length;
          _sendPacketToDataChannel(bytes);
        }
      });

      _connectionState = VpnConnectionState.connected;
      _connectedSince = DateTime.now();
      _currentIp = '10.0.0.2';

      _connectionTimeoutTimer?.cancel();

      // Start stats timer for speed calculation
      _startStatsTimer();

      notifyListeners();
    } catch (e) {
      print('Failed to start VPN Service: $e');
      disconnect();
    }
  }

  /// Start timer to update speed stats every second
  void _startStatsTimer() {
    _statsTimer?.cancel();
    _lastBytesSent = 0;
    _lastBytesReceived = 0;

    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateStats();
    });
  }

  /// Update speed stats from peer connection stats
  Future<void> _updateStats() async {
    if (_peerConnection == null) return;

    try {
      final stats = await _peerConnection!.getStats();

      int totalBytesSent = 0;
      int totalBytesReceived = 0;

      for (final report in stats) {
        // Only count bytes from the main transport to avoid double-counting
        if (report.type == 'transport' || report.type == 'data-channel') {
          final values = report.values;
          if (values.containsKey('bytesSent')) {
            totalBytesSent = (values['bytesSent'] as num).toInt();
          }
          if (values.containsKey('bytesReceived')) {
            totalBytesReceived = (values['bytesReceived'] as num).toInt();
          }
          break; // We found the main data flow, no need to keep looping
        }
      }

      // Calculate speed (bytes per second)
      if (_lastBytesSent > 0) {
        _uploadSpeed = totalBytesSent - _lastBytesSent;
        if (_uploadSpeed < 0) _uploadSpeed = 0;
      }
      if (_lastBytesReceived > 0) {
        _downloadSpeed = totalBytesReceived - _lastBytesReceived;
        if (_downloadSpeed < 0) _downloadSpeed = 0;
      }

      _lastBytesSent = totalBytesSent;
      _lastBytesReceived = totalBytesReceived;

      notifyListeners();
    } catch (e) {
      print('Stats update error: $e');
    }
  }

  Future<void> disconnect() async {
    // Stop background service notification
    try {
      FlutterBackgroundService().invoke("stopService");
    } catch (e) {
      print('Background service stop error: $e');
    }

    try {
      await _controlChannel.invokeMethod('stop');
    } catch (e) {}

    await _packetSubscription?.cancel();
    _packetSubscription = null;

    _statsTimer?.cancel();
    _statsTimer = null;

    await _dataChannel?.close();
    await _peerConnection?.close();
    await _signalingSocket?.close();

    _dataChannel = null;
    _peerConnection = null;
    _signalingSocket = null;

    _connectionState = VpnConnectionState.disconnected;
    _currentIp = '---';
    _connectedSince = null;
    _uploadSpeed = 0;
    _downloadSpeed = 0;

    _connectionTimeoutTimer?.cancel();
    _remoteCandidates.clear();
    _remoteDescriptionSet = false;

    notifyListeners();
  }

  void _handleSignalingMessage(dynamic rawMessage) async {
    try {
      final data = jsonDecode(rawMessage);
      final String? type = data['type'];

      if (type == 'answer') {
        print("I/flutter: Setting Remote Description from Answer");

        try {
          var sdpData = data['sdp'];
          String? sdpString;
          String? sdpType;

          // Handle if 'sdp' is a nested Map (from Go) or a direct value
          if (sdpData is Map) {
            sdpString = sdpData['sdp'];
            sdpType = sdpData['type'];
          } else {
            sdpString = sdpData;
            sdpType = 'answer';
          }

          if (sdpString != null) {
            await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(sdpString, sdpType ?? 'answer'),
            );
            print("I/flutter: Remote Description Set Successfully!");

            _remoteDescriptionSet = true;

            // Drain queued candidates
            print('Draining ${_remoteCandidates.length} queued candidates');
            for (final candidate in _remoteCandidates) {
              await _peerConnection?.addCandidate(candidate);
            }
            _remoteCandidates.clear();
          }
        } catch (e) {
          print("I/flutter: Signaling Error during Answer: $e");
        }
      } else if (type == 'candidate') {
        try {
          final candidateData = data['candidate'];
          if (candidateData != null && _peerConnection != null) {
            String? candidateStr;
            String? sdpMid;
            int? sdpMLineIndex;

            if (candidateData is Map) {
              candidateStr = candidateData['candidate']?.toString();
              sdpMid = candidateData['sdpMid']?.toString();
              sdpMLineIndex =
                  candidateData['sdpMLineIndex'] is int
                      ? candidateData['sdpMLineIndex']
                      : int.tryParse(
                        candidateData['sdpMLineIndex']?.toString() ?? "",
                      );
            } else {
              candidateStr = candidateData.toString();
            }

            if (candidateStr != null) {
              final candidate = RTCIceCandidate(
                candidateStr,
                sdpMid,
                sdpMLineIndex,
              );

              if (_remoteDescriptionSet) {
                await _peerConnection!.addCandidate(candidate);
              } else {
                print('Queueing ICE Candidate (Remote Description not set)');
                _remoteCandidates.add(candidate);
              }
            }
          }
        } catch (e) {
          print("I/flutter: Candidate Error: $e");
        }
      }
    } catch (e) {
      print('Signaling Error: $e');
    }
  }

  void _sendSignalingMessage(Map<String, dynamic> msg) {
    // Ensure all messages have from/to fields
    msg['from'] = _deviceId;
    msg['to'] = msg['to'] ?? 'laptop_gateway';
    _signalingSocket?.add(jsonEncode(msg));
  }

  void _sendPacketToDataChannel(Uint8List packet) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel?.send(RTCDataChannelMessage.fromBinary(packet));
    }
  }

  void _sendPacketToNative(Uint8List packet) {
    _controlChannel.invokeMethod('write', {'packet': packet});
  }

  Future<void> toggleConnection() async {
    if (_connectionState == VpnConnectionState.connected ||
        _connectionState == VpnConnectionState.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  // Not used in this version but kept for compatibility
  void simulateReconnection() {}

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

  Future<void> setServerEndpoint(String value) async {
    _serverEndpoint = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_endpoint', value);
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _statsTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    super.dispose();
  }
}
