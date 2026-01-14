package com.example.chakra

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Chakra Foreground Service
 * Manages VPN lifecycle and provides persistent notification with connect/disconnect actions
 * Notification persists even when app is closed from recent apps
 */
class ChakraForegroundService : Service() {
    private val binder = LocalBinder()
    private val handler = Handler(Looper.getMainLooper())
    
    private var vpnService: ChakraVpnService? = null
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    
    private var shouldBeConnected = false
    private var reconnectRetryCount = 0
    private val maxRetries = 5
    private val baseDelayMs = 2000L
    
    private var currentStatus: VpnStatus = VpnStatus.Disconnected
    
    companion object {
        private const val TAG = "ChakraForegroundService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "chakra_vpn_channel"
        
        const val ACTION_CONNECT = "com.example.chakra.ACTION_CONNECT"
        const val ACTION_DISCONNECT = "com.example.chakra.ACTION_DISCONNECT"
        const val ACTION_SET_KILL_SWITCH = "com.example.chakra.ACTION_SET_KILL_SWITCH"
        
        private var instance: ChakraForegroundService? = null
        
        fun getInstance(): ChakraForegroundService? = instance
        
        fun getCurrentStatus(): Map<String, Any?> {
            return instance?.getStatusMap() ?: mapOf(
                "status" to "disconnected",
                "publicIp" to null,
                "latency" to null,
                "bytesSent" to null,
                "bytesReceived" to null,
                "uptime" to null
            )
        }
    }
    
    enum class VpnStatus {
        Disconnected, Connecting, Connected, Reconnecting, Error
    }
    
    inner class LocalBinder : Binder() {
        fun getService(): ChakraForegroundService = this@ChakraForegroundService
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        createNotificationChannel()
        Log.d(TAG, "Foreground Service created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val endpoint = intent.getStringExtra("endpoint") ?: ""
                val clientPrivateKey = intent.getStringExtra("clientPrivateKey") ?: ""
                val clientPublicKey = intent.getStringExtra("clientPublicKey") ?: ""
                val clientIpAddress = intent.getStringExtra("clientIpAddress") ?: ""
                val allowedIps = intent.getStringExtra("allowedIps") ?: "0.0.0.0/0"
                
                connectVpn(endpoint, clientPrivateKey, clientPublicKey, clientIpAddress, allowedIps)
            }
            ACTION_DISCONNECT -> {
                disconnectVpn()
            }
            ACTION_SET_KILL_SWITCH -> {
                val enabled = intent.getBooleanExtra("enabled", false)
                setKillSwitch(enabled)
            }
        }
        
        // Start foreground immediately to keep service alive
        startForeground(NOTIFICATION_ID, buildNotification())
        
        // Return START_STICKY so service restarts if killed
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder = binder
    
    override fun onDestroy() {
        super.onDestroy()
        disconnectVpn()
        unregisterNetworkCallback()
        instance = null
        Log.d(TAG, "Foreground Service destroyed")
    }
    
    /**
     * Create notification channel (required for Android O+)
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Chakra VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status and controls"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    /**
     * Build persistent notification with connect/disconnect actions
     */
    private fun buildNotification(): Notification {
        val title = "Chakra VPN"
        val (text, infoText) = when (currentStatus) {
            VpnStatus.Connected -> "Connected – Protected in background" to "VPN remains active even when app is closed"
            VpnStatus.Reconnecting -> "Reconnecting…" to "VPN remains active even when app is closed"
            VpnStatus.Connecting -> "Connecting…" to "VPN remains active even when app is closed"
            VpnStatus.Error -> "Error – Tap for details" to "VPN remains active even when app is closed"
            VpnStatus.Disconnected -> "Disconnected" to "VPN remains active even when app is closed"
        }
        
        // Intent to open app
        val openAppIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Connect action
        val connectIntent = PendingIntent.getService(
            this, 1,
            Intent(this, ChakraForegroundService::class.java).apply {
                action = ACTION_CONNECT
                // Reuse last connection params
                putExtra("endpoint", getLastEndpoint())
                putExtra("clientPrivateKey", getLastPrivateKey())
                putExtra("clientPublicKey", getLastPublicKey())
                putExtra("clientIpAddress", getLastIpAddress())
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Disconnect action
        val disconnectIntent = PendingIntent.getService(
            this, 2,
            Intent(this, ChakraForegroundService::class.java).apply {
                action = ACTION_DISCONNECT
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info) // TODO: Replace with custom icon
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$text\n$infoText"))
            .setOngoing(true) // Persistent notification
            .setContentIntent(openAppIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setShowWhen(false)
        
        // Add action buttons based on status
        when (currentStatus) {
            VpnStatus.Connected, VpnStatus.Reconnecting -> {
                builder.addAction(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Disconnect",
                    disconnectIntent
                )
            }
            VpnStatus.Disconnected, VpnStatus.Error -> {
                builder.addAction(
                    android.R.drawable.ic_menu_upload,
                    "Connect",
                    connectIntent
                )
            }
            VpnStatus.Connecting -> {
                // No action while connecting
            }
        }
        
        return builder.build()
    }
    
    /**
     * Update notification
     */
    private fun updateNotification() {
        val notification = buildNotification()
        val notificationManager = NotificationManagerCompat.from(this)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    /**
     * Connect VPN
     * Note: allowedIps is passed for contract explicitness.
     * Native layer (ChakraVpnService) currently hardcodes 0.0.0.0/0 but should enforce this parameter.
     */
    private fun connectVpn(
        endpoint: String,
        clientPrivateKey: String,
        clientPublicKey: String,
        clientIpAddress: String,
        allowedIps: String = "0.0.0.0/0"
    ) {
        if (shouldBeConnected && currentStatus == VpnStatus.Connected) {
            Log.d(TAG, "VPN already connected")
            return
        }
        
        shouldBeConnected = true
        reconnectRetryCount = 0
        currentStatus = VpnStatus.Connecting
        updateNotification()
        
        // Request VPN permission and start VPN service
        val vpnIntent = VpnService.prepare(this)
        if (vpnIntent != null) {
            // Permission not granted, need user approval
            vpnIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(vpnIntent)
            currentStatus = VpnStatus.Error
            updateNotification()
            return
        }
        
        // Start VPN service
        vpnService = ChakraVpnService()
        
        val serverPublicKey = ChakraVpnBackend.getServerPublicKey()
        val success = vpnService?.connect(
            clientPrivateKey,
            clientPublicKey,
            clientIpAddress,
            serverPublicKey,
            endpoint
        ) ?: false
        
        if (success) {
            currentStatus = VpnStatus.Connected
            registerNetworkCallback()
            saveLastConnectionParams(endpoint, clientPrivateKey, clientPublicKey, clientIpAddress)
        } else {
            currentStatus = VpnStatus.Error
            shouldBeConnected = false
        }
        
        updateNotification()
    }
    
    /**
     * Disconnect VPN
     */
    private fun disconnectVpn() {
        shouldBeConnected = false
        reconnectRetryCount = 0
        
        vpnService?.disconnect()
        vpnService = null
        unregisterNetworkCallback()
        
        currentStatus = VpnStatus.Disconnected
        updateNotification()
        
        // Optionally stop foreground (but keep notification for quick reconnect)
        // stopForeground(true)
    }
    
    /**
     * Register network callback for auto-reconnect
     */
    private fun registerNetworkCallback() {
        unregisterNetworkCallback()
        
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                Log.d(TAG, "Network available")
                if (shouldBeConnected && currentStatus != VpnStatus.Connected) {
                    scheduleReconnect()
                }
            }
            
            override fun onLost(network: Network) {
                Log.d(TAG, "Network lost")
                if (shouldBeConnected && currentStatus == VpnStatus.Connected) {
                    currentStatus = VpnStatus.Reconnecting
                    updateNotification()
                    scheduleReconnect()
                }
            }
            
            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                if (shouldBeConnected && currentStatus != VpnStatus.Connected) {
                    scheduleReconnect()
                }
            }
        }
        
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        
        connectivityManager?.registerNetworkCallback(request, networkCallback!!)
    }
    
    /**
     * Unregister network callback
     */
    private fun unregisterNetworkCallback() {
        networkCallback?.let {
            connectivityManager?.unregisterNetworkCallback(it)
            networkCallback = null
        }
    }
    
    /**
     * Schedule reconnect with exponential backoff
     */
    private fun scheduleReconnect() {
        if (!shouldBeConnected) return
        if (reconnectRetryCount >= maxRetries) {
            currentStatus = VpnStatus.Error
            updateNotification()
            return
        }
        
        val delay = (baseDelayMs * (1 shl reconnectRetryCount)).coerceAtMost(30000L)
        reconnectRetryCount++
        
        currentStatus = VpnStatus.Reconnecting
        updateNotification()
        
        handler.postDelayed({
            if (!shouldBeConnected) return@postDelayed
            
            val endpoint = getLastEndpoint()
            val clientPrivateKey = getLastPrivateKey()
            val clientPublicKey = getLastPublicKey()
            val clientIpAddress = getLastIpAddress()
            
            if (endpoint.isNotEmpty() && clientPrivateKey.isNotEmpty()) {
                connectVpn(endpoint, clientPrivateKey, clientPublicKey, clientIpAddress, "0.0.0.0/0")
            }
        }, delay)
    }
    
    /**
     * Get status map for Flutter
     */
    fun getStatusMap(): Map<String, Any?> {
        val statusStr = when (currentStatus) {
            VpnStatus.Connected -> "connected"
            VpnStatus.Connecting -> "connecting"
            VpnStatus.Reconnecting -> "reconnecting"
            VpnStatus.Disconnected -> "disconnected"
            VpnStatus.Error -> "error"
        }
        
        val stats = vpnService?.getStats() ?: emptyMap<String, Any>()
        
        return mapOf(
            "status" to statusStr,
            "publicIp" to null, // TODO: Get from VPN stats
            "latency" to null, // TODO: Calculate latency
            "bytesSent" to (stats["bytesSent"] as? Long ?: 0L),
            "bytesReceived" to (stats["bytesReceived"] as? Long ?: 0L),
            "uptime" to 0 // TODO: Calculate uptime
        )
    }
    
    /**
     * Save last connection parameters for reconnect
     */
    private fun saveLastConnectionParams(
        endpoint: String,
        clientPrivateKey: String,
        clientPublicKey: String,
        clientIpAddress: String
    ) {
        getSharedPreferences("chakra_vpn", Context.MODE_PRIVATE).edit()
            .putString("last_endpoint", endpoint)
            .putString("last_private_key", clientPrivateKey)
            .putString("last_public_key", clientPublicKey)
            .putString("last_ip_address", clientIpAddress)
            .apply()
    }
    
    private fun getLastEndpoint(): String =
        getSharedPreferences("chakra_vpn", Context.MODE_PRIVATE)
            .getString("last_endpoint", "") ?: ""
    
    private fun getLastPrivateKey(): String =
        getSharedPreferences("chakra_vpn", Context.MODE_PRIVATE)
            .getString("last_private_key", "") ?: ""
    
    private fun getLastPublicKey(): String =
        getSharedPreferences("chakra_vpn", Context.MODE_PRIVATE)
            .getString("last_public_key", "") ?: ""
    
    private fun getLastIpAddress(): String =
        getSharedPreferences("chakra_vpn", Context.MODE_PRIVATE)
            .getString("last_ip_address", "") ?: ""
    
    /**
     * Set kill switch state
     * Note: On Android, true kill switch enforcement requires system-level
     * "Block connections without VPN" setting. This method stores the preference
     * and the native layer should enforce it by blocking non-VPN traffic when enabled.
     */
    private fun setKillSwitch(enabled: Boolean) {
        getSharedPreferences("chakra_vpn", Context.MODE_PRIVATE).edit()
            .putBoolean("kill_switch_enabled", enabled)
            .apply()
        Log.d(TAG, "Kill switch ${if (enabled) "enabled" else "disabled"}")
        // TODO: Implement actual kill switch enforcement (block non-VPN traffic when enabled)
        // This typically requires system-level settings or firewall rules
    }
}
