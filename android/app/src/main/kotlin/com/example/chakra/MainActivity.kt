package com.example.chakra

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.example.chakra/vpn"
    private val STATUS_CHANNEL = "com.example.chakra/vpn_status"
    
    private var statusEventSink: EventChannel.EventSink? = null
    private var statusUpdateRunnable: Runnable? = null
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Method channel for VPN operations
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    // Start status update stream
                    startStatusUpdates()
                    result.success(true)
                }
                "requestPermission" -> {
                    // VPN permission is requested when starting VpnService
                    result.success(true)
                }
                "connect" -> {
                    val endpoint = call.argument<String>("endpoint") ?: ""
                    val clientPrivateKey = call.argument<String>("clientPrivateKey") ?: ""
                    val clientPublicKey = call.argument<String>("clientPublicKey") ?: ""
                    val clientIpAddress = call.argument<String>("clientIpAddress") ?: ""
                    val allowedIps = call.argument<String>("allowedIps") ?: "0.0.0.0/0"
                    
                    val intent = Intent(this, ChakraForegroundService::class.java).apply {
                        action = ChakraForegroundService.ACTION_CONNECT
                        putExtra("endpoint", endpoint)
                        putExtra("clientPrivateKey", clientPrivateKey)
                        putExtra("clientPublicKey", clientPublicKey)
                        putExtra("clientIpAddress", clientIpAddress)
                        putExtra("allowedIps", allowedIps)
                    }
                    startForegroundService(intent)
                    result.success(true)
                }
                "disconnect" -> {
                    val intent = Intent(this, ChakraForegroundService::class.java).apply {
                        action = ChakraForegroundService.ACTION_DISCONNECT
                    }
                    startForegroundService(intent)
                    result.success(true)
                }
                "getStatus" -> {
                    val status = ChakraForegroundService.getCurrentStatus()
                    result.success(status)
                }
                "getOrCreateKeypair" -> {
                    val keypair = ChakraVpnBackend.getOrCreateKeypair(this)
                    result.success(keypair)
                }
                "setKillSwitchEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    // Forward to foreground service
                    val intent = Intent(this, ChakraForegroundService::class.java).apply {
                        action = ChakraForegroundService.ACTION_SET_KILL_SWITCH
                        putExtra("enabled", enabled)
                    }
                    startForegroundService(intent)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Event channel for status updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STATUS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    statusEventSink = events
                    startStatusUpdates()
                }
                
                override fun onCancel(arguments: Any?) {
                    statusEventSink = null
                    stopStatusUpdates()
                }
            }
        )
    }
    
    private fun startStatusUpdates() {
        stopStatusUpdates()
        statusUpdateRunnable = object : Runnable {
            override fun run() {
                val status = ChakraForegroundService.getCurrentStatus()
                statusEventSink?.success(status)
                handler.postDelayed(this, 2000) // Update every 2 seconds
            }
        }
        handler.post(statusUpdateRunnable!!)
    }
    
    private fun stopStatusUpdates() {
        statusUpdateRunnable?.let { handler.removeCallbacks(it) }
        statusUpdateRunnable = null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopStatusUpdates()
    }
}
