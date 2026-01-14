import Flutter
import UIKit
import NetworkExtension
import Security

/// VPN Platform Channel Handler for iOS
/// Manages WireGuard VPN via Network Extension
class VpnPlatformChannel: NSObject, FlutterPlugin {
    private static let CHANNEL_NAME = "com.example.chakra/vpn"
    private static let STATUS_CHANNEL_NAME = "com.example.chakra/vpn_status"
    
    private var statusEventSink: FlutterEventSink?
    private var statusTimer: Timer?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VpnPlatformChannel()
        
        // Method channel
        let methodChannel = FlutterMethodChannel(
            name: CHANNEL_NAME,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        // Event channel
        let eventChannel = FlutterEventChannel(
            name: STATUS_CHANNEL_NAME,
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(result: result)
        case "requestPermission":
            // iOS handles VPN permission automatically via Network Extension
            result(true)
        case "getOrCreateKeypair":
            getOrCreateKeypair(result: result)
        case "connect":
            connect(call: call, result: result)
        case "disconnect":
            disconnect(result: result)
        case "getStatus":
            getStatus(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initialize(result: @escaping FlutterResult) {
        startStatusUpdates()
        result(true)
    }
    
    private func getOrCreateKeypair(result: @escaping FlutterResult) {
        let keychain = KeychainService.shared
        
        if let privateKey = keychain.getPrivateKey(),
           let publicKey = keychain.getPublicKey() {
            result([
                "privateKey": privateKey,
                "publicKey": publicKey,
                "ipAddress": "10.66.66.2/32"
            ])
            return
        }
        
        // Generate new keypair
        // TODO: Use actual WireGuard library for key generation
        // For now, placeholder implementation
        let keypair = generateWireGuardKeypair()
        
        keychain.savePrivateKey(keypair.privateKey)
        keychain.savePublicKey(keypair.publicKey)
        
        result([
            "privateKey": keypair.privateKey,
            "publicKey": keypair.publicKey,
            "ipAddress": "10.66.66.2/32"
        ])
    }
    
    private func generateWireGuardKeypair() -> (privateKey: String, publicKey: String) {
        // Placeholder - MUST use WireGuard library in production
        // com.wireguard.ios.WireGuard.generateKeypair()
        let privateKeyData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let privateKey = privateKeyData.base64EncodedString()
        
        // Generate public key from private (simplified - use real WireGuard crypto)
        var publicKeyData = privateKeyData
        publicKeyData[0] ^= 0xFF
        let publicKey = publicKeyData.base64EncodedString()
        
        return (privateKey, publicKey)
    }
    
    private func connect(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let endpoint = args["endpoint"] as? String,
              let clientPrivateKey = args["clientPrivateKey"] as? String,
              let clientPublicKey = args["clientPublicKey"] as? String,
              let clientIpAddress = args["clientIpAddress"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required parameters", details: nil))
            return
        }
        
        let serverPublicKey = "YFjlqgULP4hKxYHGM1e/MtzVfuzBMjSysPxSGUnn6lc="
        let serverEndpoint = endpoint
        
        // Save user intent
        UserDefaults.standard.set(true, forKey: "should_be_connected")
        UserDefaults.standard.set(endpoint, forKey: "last_endpoint")
        UserDefaults.standard.set(clientPrivateKey, forKey: "last_private_key")
        UserDefaults.standard.set(clientPublicKey, forKey: "last_public_key")
        UserDefaults.standard.set(clientIpAddress, forKey: "last_ip_address")
        
        // Configure and start VPN
        configureAndStartVPN(
            endpoint: serverEndpoint,
            clientPrivateKey: clientPrivateKey,
            clientPublicKey: clientPublicKey,
            clientIpAddress: clientIpAddress,
            serverPublicKey: serverPublicKey,
            result: result
        )
    }
    
    private func configureAndStartVPN(
        endpoint: String,
        clientPrivateKey: String,
        clientPublicKey: String,
        clientIpAddress: String,
        serverPublicKey: String,
        result: @escaping FlutterResult
    ) {
        // Parse endpoint
        let endpointParts = endpoint.split(separator: ":")
        guard endpointParts.count == 2,
              let port = UInt16(endpointParts[1]) else {
            result(FlutterError(code: "INVALID_ENDPOINT", message: "Invalid endpoint format", details: nil))
            return
        }
        let serverAddress = String(endpointParts[0])
        
        // Parse client IP
        let ipParts = clientIpAddress.split(separator: "/")
        guard ipParts.count == 2,
              let prefixLength = UInt8(ipParts[1]) else {
            result(FlutterError(code: "INVALID_IP", message: "Invalid IP address format", details: nil))
            return
        }
        let clientIP = String(ipParts[0])
        
        // Create VPN configuration
        // TODO: Use WireGuard iOS library (wireguard-apple)
        // For now, this is a placeholder that shows the structure
        
        // In production, use:
        // let tunnel = NETunnelProviderManager()
        // Configure with WireGuard settings
        // tunnel.isEnabled = true
        // tunnel.saveToPreferences { error in ... }
        // tunnel.connection.startVPNTunnel()
        
        // Placeholder: simulate success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            result(true)
        }
    }
    
    private func disconnect(result: @escaping FlutterResult) {
        UserDefaults.standard.set(false, forKey: "should_be_connected")
        
        // Stop VPN tunnel
        // TODO: Use WireGuard iOS library
        // let tunnel = NETunnelProviderManager()
        // tunnel.connection.stopVPNTunnel()
        
        result(true)
    }
    
    private func getStatus(result: @escaping FlutterResult) {
        // TODO: Get actual status from NETunnelProviderManager
        let shouldBeConnected = UserDefaults.standard.bool(forKey: "should_be_connected")
        
        // Placeholder status
        result([
            "status": shouldBeConnected ? "connected" : "disconnected",
            "publicIp": nil,
            "latency": nil,
            "bytesSent": nil,
            "bytesReceived": nil,
            "uptime": nil
        ])
    }
    
    private func startStatusUpdates() {
        stopStatusUpdates()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }
    
    private func stopStatusUpdates() {
        statusTimer?.invalidate()
        statusTimer = nil
    }
    
    private func updateStatus() {
        getStatus { [weak self] status in
            self?.statusEventSink?(status)
        }
    }
}

// MARK: - FlutterStreamHandler
extension VpnPlatformChannel: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        statusEventSink = events
        startStatusUpdates()
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        statusEventSink = nil
        stopStatusUpdates()
        return nil
    }
}

// MARK: - Keychain Service
class KeychainService {
    static let shared = KeychainService()
    private let service = "com.example.chakra.vpn"
    
    private init() {}
    
    func savePrivateKey(_ key: String) {
        save(key: "private_key", value: key)
    }
    
    func getPrivateKey() -> String? {
        return get(key: "private_key")
    }
    
    func savePublicKey(_ key: String) {
        save(key: "public_key", value: key)
    }
    
    func getPublicKey() -> String? {
        return get(key: "public_key")
    }
    
    private func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
}
