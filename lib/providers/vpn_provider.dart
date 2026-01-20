import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VpnConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class VpnProvider extends ChangeNotifier {
  VpnConnectionState _connectionState = VpnConnectionState.disconnected;
  String _currentIp = '---';
  int _latency = 0;
  int _uploadBytes = 0;
  int _downloadBytes = 0;
  DateTime? _connectedSince;
  bool _autoConnect = false;
  bool _killSwitch = false;
  String _serverEndpoint = 'wss://chakra-1zg5.onrender.com/ws';

  // WebRTC & Platform Channels
  WebSocket? _signalingSocket;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  static const _controlChannel = MethodChannel('com.chakra.vpn/control');
  static const _packetChannel = EventChannel('com.chakra.vpn/packets');
  StreamSubscription? _packetSubscription;
  Timer? _connectionTimeoutTimer;

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

  Future<void> connect() async {
    if (_connectionState == VpnConnectionState.connected) return;

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
          // Optional: Retry once automatically? For now, just disconnect and let user/auto-reconnect handle it.
          // If auto-connect is on, it might loop, so be careful.
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
          _uploadBytes += message.binary.length;
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
      _sendSignalingMessage({'type': 'offer', 'sdp': offer?.sdp});
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
        notifyListeners();
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
      notifyListeners();
    } catch (e) {
      print('Failed to start VPN Service: $e');
      disconnect();
    }
  }

  Future<void> disconnect() async {
    try {
      await _controlChannel.invokeMethod('stop');
    } catch (e) {}

    await _packetSubscription?.cancel();
    _packetSubscription = null;

    await _dataChannel?.close();
    await _peerConnection?.close();
    await _signalingSocket?.close();

    _dataChannel = null;
    _peerConnection = null;
    _signalingSocket = null;

    _connectionState = VpnConnectionState.disconnected;
    _currentIp = '---';
    _connectedSince = null;

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
}
