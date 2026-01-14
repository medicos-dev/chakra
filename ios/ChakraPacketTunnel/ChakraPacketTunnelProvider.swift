//
//  ChakraPacketTunnelProvider.swift
//  ChakraPacketTunnel
//
//  Network Extension Packet Tunnel Provider for WireGuard VPN
//  This file should be added to a separate Network Extension target in Xcode
//

import NetworkExtension
import WireGuardKit

/// Packet Tunnel Provider for Chakra VPN
/// Handles WireGuard tunnel lifecycle and packet forwarding
class ChakraPacketTunnelProvider: NEPacketTunnelProvider {
    
    private var wireguardTunnel: WireGuardTunnel?
    private var isRunning = false
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Get configuration from options or UserDefaults
        guard let config = getWireGuardConfig() else {
            completionHandler(NSError(domain: "ChakraVPN", code: 1, userInfo: [NSLocalizedDescriptionKey: "No VPN configuration found"]))
            return
        }
        
        // Create WireGuard tunnel
        do {
            wireguardTunnel = try WireGuardTunnel(configuration: config)
            isRunning = true
            
            // Set network settings
            let networkSettings = createNetworkSettings(config: config)
            setTunnelNetworkSettings(networkSettings) { error in
                if let error = error {
                    completionHandler(error)
                    return
                }
                
                // Start WireGuard tunnel
                self.wireguardTunnel?.start { error in
                    completionHandler(error)
                }
            }
        } catch {
            completionHandler(error)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        wireguardTunnel?.stop()
        wireguardTunnel = nil
        isRunning = false
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from main app
        completionHandler?(nil)
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Handle sleep
        completionHandler()
    }
    
    override func wake() {
        // Handle wake
    }
    
    // MARK: - Helper Methods
    
    private func getWireGuardConfig() -> WireGuardConfiguration? {
        // Load configuration from UserDefaults (shared with main app)
        guard let endpoint = UserDefaults(suiteName: "group.com.example.chakra")?.string(forKey: "last_endpoint"),
              let clientPrivateKey = UserDefaults(suiteName: "group.com.example.chakra")?.string(forKey: "last_private_key"),
              let clientPublicKey = UserDefaults(suiteName: "group.com.example.chakra")?.string(forKey: "last_public_key"),
              let clientIpAddress = UserDefaults(suiteName: "group.com.example.chakra")?.string(forKey: "last_ip_address") else {
            return nil
        }
        
        let serverPublicKey = "YFjlqgULP4hKxYHGM1e/MtzVfuzBMjSysPxSGUnn6lc="
        
        // Parse endpoint
        let endpointParts = endpoint.split(separator: ":")
        guard endpointParts.count == 2,
              let port = UInt16(endpointParts[1]) else {
            return nil
        }
        let serverAddress = String(endpointParts[0])
        
        // Build WireGuard configuration
        // Format: [Interface]\nPrivateKey = ...\nAddress = ...\n[Peer]\nPublicKey = ...\nEndpoint = ...\nAllowedIPs = 0.0.0.0/0\nPersistentKeepalive = 25
        var configString = "[Interface]\n"
        configString += "PrivateKey = \(clientPrivateKey)\n"
        configString += "Address = \(clientIpAddress)\n"
        // NO DNS - OS handles DNS resolution
        configString += "\n[Peer]\n"
        configString += "PublicKey = \(serverPublicKey)\n"
        configString += "Endpoint = \(serverAddress):\(port)\n"
        configString += "AllowedIPs = 0.0.0.0/0\n"
        configString += "PersistentKeepalive = 25\n"
        
        return try? WireGuardConfiguration(from: configString)
    }
    
    private func createNetworkSettings(config: WireGuardConfiguration) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.66.66.1")
        
        // Set IP address
        if let ipAddress = config.interface?.addresses.first {
            settings.ipv4Settings = NEIPv4Settings(addresses: [ipAddress.address], subnetMasks: [ipAddress.netmask])
        }
        
        // Full tunnel: route all traffic
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        
        // NO DNS configured - OS handles DNS resolution
        
        // Set MTU
        settings.mtu = NSNumber(value: 1420)
        
        return settings
    }
}
