package com.example.chakra

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Boot Receiver
 * Handles boot-time auto-reconnection for VPN
 * Reads should_be_connected from SharedPreferences and restarts VPN service if needed
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Boot completed, checking VPN reconnect state")
            
            // Read should_be_connected from SharedPreferences
            val prefs = context.getSharedPreferences("chakra_vpn", Context.MODE_PRIVATE)
            val shouldBeConnected = prefs.getBoolean("should_be_connected", false)
            
            if (shouldBeConnected) {
                Log.d(TAG, "should_be_connected is true, attempting VPN reconnect")
                
                // Get last connection parameters
                val endpoint = prefs.getString("last_endpoint", "") ?: ""
                val clientPrivateKey = prefs.getString("last_private_key", "") ?: ""
                val clientPublicKey = prefs.getString("last_public_key", "") ?: ""
                val clientIpAddress = prefs.getString("last_ip_address", "") ?: ""
                
                // Only reconnect if we have valid connection parameters
                if (endpoint.isNotEmpty() && clientPrivateKey.isNotEmpty()) {
                    val serviceIntent = Intent(context, ChakraForegroundService::class.java).apply {
                        action = ChakraForegroundService.ACTION_CONNECT
                        putExtra("endpoint", endpoint)
                        putExtra("clientPrivateKey", clientPrivateKey)
                        putExtra("clientPublicKey", clientPublicKey)
                        putExtra("clientIpAddress", clientIpAddress)
                        putExtra("allowedIps", "0.0.0.0/0")
                    }
                    
                    // Start foreground service (Android O+ requires startForegroundService)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                    
                    Log.d(TAG, "VPN reconnect request sent after boot")
                } else {
                    Log.w(TAG, "Cannot reconnect: missing connection parameters")
                }
            } else {
                Log.d(TAG, "should_be_connected is false, skipping VPN reconnect")
            }
        }
    }
}
