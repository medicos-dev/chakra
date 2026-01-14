# Chakra VPN - Setup Guide

## Overview

Chakra VPN is a production-grade, single-server VPN mobile app that routes all internet traffic through a self-hosted WireGuard server on a Windows laptop.

## Architecture

- **Single Server Model**: Exactly ONE VPN server (no switching)
- **Full Tunnel VPN**: All traffic (`0.0.0.0/0`) routed through VPN
- **No DNS Configuration**: OS/system handles DNS resolution (no DNS field in config)
- **Background Persistence**: VPN survives app closure, screen lock, process kills
- **Auto-Reconnect**: Automatically reconnects on network changes

## Server Configuration

### Windows WireGuard Server Setup

**Server Interface Name**: `acer-naskar`

**Server Keys**:
- PrivateKey: `AAnZh/hv/JSu+E2RAqttY2mygwNksPIRQ11UolG4W8=`
- PublicKey: `YFjlqgULP4hKxYHGM1e/MtzVfuzBMjSysPxSGUnn6lc=`

**Server Interface Configuration**:
```ini
[Interface]
Address = 10.66.66.1/24
ListenPort = 51820
PrivateKey = AAnZh/hv/JSu+E2RAqttY2mygwNksPIRQ11UolG4W8=
```

**Important**: No DNS configured on server (intentional and correct).

### Adding Client Peer

For each device that connects via the app, add a `[Peer]` block to the server config:

```ini
[Peer]
# Device's public key (generated on the phone)
PublicKey = <CLIENT_PUBLIC_KEY>

# Assign unique /32 in 10.66.66.0/24 for this device
# Example for first device:
AllowedIPs = 10.66.66.2/32

# Optional but recommended for NAT traversal
PersistentKeepalive = 25
```

**Rules**:
- Each device gets a **unique** `10.66.66.X/32` inside `10.66.66.0/24`
- Only one `[Peer]` per device
- Do NOT add DNS or other fields on the server

### Network Configuration

- **Laptop LAN IP**: `192.168.1.41`
- **Router**: UDP port `51820` forwarded to `192.168.1.41`
- **Public Endpoint**: `<public-ip>:51820` (Dynamic IP, DDNS-ready)

## Client Configuration

### App Configuration

Before connecting, you **MUST** set the server endpoint in `lib/providers/vpn_provider.dart`:

```dart
static const String serverEndpoint = 'your-ddns-hostname.ddns.net:51820';
// OR
static const String serverEndpoint = '123.45.67.89:51820';
```

### Generated Client Config (Internal)

The app generates this config internally (not shown to user):

```ini
[Interface]
PrivateKey = <generated_on_device>
Address = 10.66.66.2/32
# NO DNS - OS handles DNS resolution

[Peer]
PublicKey = YFjlqgULP4hKxYHGM1e/MtzVfuzBMjSysPxSGUnn6lc=
Endpoint = <public-ip>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

**Key Points**:
- DNS is **NOT** set in client config (OS handles DNS)
- Each device generates its own WireGuard keypair
- Only registered client public keys are added as peers on server
- Security relies purely on WireGuard cryptographic keys

## Platform-Specific Implementation

### Android

**Components**:
- `ChakraVpnService`: Extends `VpnService`, creates TUN interface
- `ChakraForegroundService`: Foreground service with persistent notification
- `ChakraVpnBackend`: Keypair generation and secure storage

**Features**:
- Persistent notification with Connect/Disconnect actions
- Notification survives app closure
- Auto-reconnect on network changes
- Secure key storage via Android Keystore + EncryptedSharedPreferences

**Permissions** (already configured in AndroidManifest.xml):
- `BIND_VPN_SERVICE`
- `FOREGROUND_SERVICE`
- `INTERNET`
- `ACCESS_NETWORK_STATE`
- `POST_NOTIFICATIONS`

**Important**: The notification tray shows Connect/Disconnect buttons that work even when the app is closed.

### iOS

**Components**:
- `VpnPlatformChannel`: Platform channel handler
- `ChakraPacketTunnelProvider`: Network Extension packet tunnel provider
- `KeychainService`: Secure key storage

**Setup Required**:
1. Create a Network Extension target in Xcode:
   - File → New → Target → Network Extension → Packet Tunnel Provider
   - Name: `ChakraPacketTunnel`
   - Copy `ChakraPacketTunnelProvider.swift` to the extension target

2. Add WireGuard iOS library:
   - Add `wireguard-apple` dependency (via Swift Package Manager or CocoaPods)
   - Import `WireGuardKit` in the packet tunnel provider

3. Configure App Groups:
   - Enable App Groups capability for both main app and extension
   - Use group: `group.com.example.chakra`

**Features**:
- VPN runs in separate process (survives app closure)
- System VPN indicator in status bar
- Auto-reconnect via Network Extension lifecycle

## State Persistence

### User Intent Storage

The app stores "user intent" (`should_be_connected`) separately from actual VPN status:

- **On Connect**: `should_be_connected = true` saved
- **On Disconnect**: `should_be_connected = false` saved
- **On App Start**: Checks `should_be_connected` and actual VPN status
  - If `should_be_connected == true` but VPN is down → auto-reconnect
  - If `should_be_connected == false` → ensure VPN is disconnected

### Background Persistence

- **Android**: Foreground Service + VpnService survive app closure
- **iOS**: Network Extension runs in separate process
- **Both**: VPN lifecycle independent of UI lifecycle

## Auto-Reconnect Logic

### Detection
- Network loss
- Wi-Fi ↔ Mobile data change
- VPN handshake timeout

### Strategy
- Exponential backoff: 2s, 4s, 8s, 16s, 30s (max)
- Max retries: 5
- Shows "Reconnecting…" state in UI
- Silent retry without user interaction

## Security

### Key Storage
- **Android**: Android Keystore + EncryptedSharedPreferences
- **iOS**: Keychain (kSecClassGenericPassword)

### No Logging
- Private keys never logged
- Only high-level connection events logged

### Kill-Switch (Optional)
- **Android**: Recommend user enable "Always-on VPN" + "Block connections without VPN" in system settings
- **iOS**: Full tunnel ensures all traffic goes through VPN

## Status & Metrics

### Exposed to UI
- **Status**: `connected`, `disconnected`, `reconnecting`, `error`
- **Metrics**:
  - Public IP
  - Latency
  - Bytes sent/received
  - Connection uptime

## UI Features

### Background Protection Indicator
- Shows "Protected in background" when connected
- Info text: "VPN remains active even when app is closed"
- Reconnect animation when reconnecting

### Notification Tray (Android)
- Persistent notification with status
- Connect/Disconnect action buttons
- Works even when app is closed

## Production Readiness Checklist

- [ ] Set server endpoint in `vpn_provider.dart`
- [ ] Add WireGuard library dependencies:
  - Android: `wireguard-android` (when available)
  - iOS: `wireguard-apple` via Swift Package Manager
- [ ] Replace placeholder key generation with real WireGuard crypto
- [ ] Test on physical devices (Android + iOS)
- [ ] Configure DDNS for dynamic IP (if needed)
- [ ] Add server peer for each device
- [ ] Test background persistence
- [ ] Test auto-reconnect
- [ ] Verify notification tray actions work
- [ ] Test kill-switch (if enabled)

## Important Notes

1. **DNS**: No DNS is configured anywhere. OS handles DNS resolution.
2. **Single Server**: Architecture assumes exactly one server. No server switching.
3. **Key Security**: Private keys never leave the device. Only public keys are shared with server.
4. **Background Operation**: VPN runs independently of app UI. Closing app does not disconnect VPN.
5. **Notification**: Android notification persists and provides Connect/Disconnect actions even when app is closed.

## Troubleshooting

### VPN Won't Connect
1. Verify server endpoint is set correctly
2. Check server peer is added with correct public key
3. Verify router port forwarding (UDP 51820)
4. Check server WireGuard service is running

### Notification Not Showing
1. Check notification permissions (Android 13+)
2. Verify foreground service is started
3. Check notification channel is created

### Auto-Reconnect Not Working
1. Verify network callback is registered
2. Check `should_be_connected` is true
3. Review retry logic logs

## WireGuard Library Integration

**Current Status**: Placeholder implementations are in place. You must integrate actual WireGuard libraries:

- **Android**: Use `wireguard-android` library (when available) or `wireguard-go` via JNI
- **iOS**: Use `wireguard-apple` library via Swift Package Manager

The placeholder code shows the structure and integration points. Replace key generation and packet handling with real WireGuard implementations.
