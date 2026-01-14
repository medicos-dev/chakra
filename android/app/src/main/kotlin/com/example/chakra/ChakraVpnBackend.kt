package com.example.chakra

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/**
 * VPN Backend Service
 * Handles WireGuard keypair generation and secure storage
 * Manages VPN tunnel lifecycle
 */
object ChakraVpnBackend {
    private const val PREFS_NAME = "chakra_vpn_prefs"
    private const val KEY_PRIVATE_KEY = "wg_private_key"
    private const val KEY_PUBLIC_KEY = "wg_public_key"
    private const val KEY_IP_ADDRESS = "wg_ip_address"
    
    // Server configuration (single server model)
    private const val SERVER_PUBLIC_KEY = "YFjlqgULP4hKxYHGM1e/MtzVfuzBMjSysPxSGUnn6lc="
    private const val CLIENT_IP_ADDRESS = "10.66.66.2/32" // Fixed IP for single device
    
    private var vpnService: ChakraVpnService? = null
    
    /**
     * Get or create WireGuard keypair
     * Uses Android Keystore for secure storage
     */
    fun getOrCreateKeypair(context: Context): Map<String, String> {
        val prefs = getEncryptedPrefs(context)
        
        var privateKey = prefs.getString(KEY_PRIVATE_KEY, null)
        var publicKey = prefs.getString(KEY_PUBLIC_KEY, null)
        val ipAddress = prefs.getString(KEY_IP_ADDRESS, CLIENT_IP_ADDRESS) ?: CLIENT_IP_ADDRESS
        
        if (privateKey == null || publicKey == null) {
            // Generate new WireGuard keypair
            // Note: In production, use actual WireGuard library (wireguard-android)
            // For now, generating placeholder keys - MUST be replaced with real WireGuard keygen
            val keypair = generateWireGuardKeypair()
            privateKey = keypair.first
            publicKey = keypair.second
            
            prefs.edit()
                .putString(KEY_PRIVATE_KEY, privateKey)
                .putString(KEY_PUBLIC_KEY, publicKey)
                .putString(KEY_IP_ADDRESS, ipAddress)
                .apply()
        }
        
        return mapOf(
            "privateKey" to privateKey,
            "publicKey" to publicKey,
            "ipAddress" to ipAddress
        )
    }
    
    /**
     * Generate WireGuard keypair
     * TODO: Replace with actual WireGuard library key generation
     * This is a placeholder - MUST use wireguard-android library in production
     */
    private fun generateWireGuardKeypair(): Pair<String, String> {
        // Placeholder implementation
        // In production, use: com.wireguard.android.crypto.KeyPair.generate()
        val randomBytes = ByteArray(32)
        java.security.SecureRandom().nextBytes(randomBytes)
        val privateKey = Base64.encodeToString(randomBytes, Base64.NO_WRAP)
        
        // Generate public key from private key (simplified - use real WireGuard crypto)
        val publicKeyBytes = randomBytes.copyOf()
        publicKeyBytes[0] = (publicKeyBytes[0].toInt() xor 0xFF).toByte()
        val publicKey = Base64.encodeToString(publicKeyBytes, Base64.NO_WRAP)
        
        return Pair(privateKey, publicKey)
    }
    
    /**
     * Get encrypted SharedPreferences for secure key storage
     */
    private fun getEncryptedPrefs(context: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        
        return EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }
    
    /**
     * Set VPN service instance
     */
    fun setVpnService(service: ChakraVpnService?) {
        vpnService = service
    }
    
    /**
     * Get current VPN service instance
     */
    fun getVpnService(): ChakraVpnService? = vpnService
    
    /**
     * Get server public key
     */
    fun getServerPublicKey(): String = SERVER_PUBLIC_KEY
    
    /**
     * Get client IP address
     */
    fun getClientIpAddress(): String = CLIENT_IP_ADDRESS
}
