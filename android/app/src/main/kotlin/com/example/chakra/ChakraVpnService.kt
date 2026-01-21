package com.example.chakra

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

class ChakraVpnService : VpnService() {

    private var mInterface: ParcelFileDescriptor? = null
    private val mRunning = AtomicBoolean(false)
    private var mThread: Thread? = null
    
    // Traffic stats
    private var bytesSent: Long = 0
    private var bytesReceived: Long = 0

    companion object {
        private const val TAG = "ChakraVpnService"
        var instance: ChakraVpnService? = null
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.i(TAG, "VPN Service Created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            return START_NOT_STICKY
        }

        if (intent.action == "STOP") {
            stopVpn()
            return START_NOT_STICKY
        }

        if (mRunning.get()) {
            return START_STICKY
        }

        // Get assigned IP from Gateway (default fallback)
        val assignedIp = intent.getStringExtra("assigned_ip") ?: "10.0.0.2"
        Log.i(TAG, "Starting VPN with assigned IP: $assignedIp")

        // START VPN with dynamic IP
        startVpn(assignedIp)
        return START_STICKY
    }

    /**
     * Connect VPN
     * Called by ChakraForegroundService
     */
    fun connect(
        clientPrivateKey: String,
        clientPublicKey: String,
        clientIpAddress: String,
        serverPublicKey: String,
        endpoint: String
    ): Boolean {
        Log.i(TAG, "Connect requested to $endpoint")
        
        // In a real implementation, we would use these parameters to configure
        // the WireGuard tunnel or passing them to the native backend.
        // For this WebRTC/Tunnel implementation, we start the VPN interface.
        
        try {
            startVpn(clientIpAddress)  // Use the provided IP address
            return mRunning.get()
        } catch (e: Exception) {
            Log.e(TAG, "Connect failed: ${e.message}")
            return false
        }
    }

    /**
     * Disconnect VPN
     */
    fun disconnect() {
        Log.i(TAG, "Disconnect requested")
        stopVpn()
    }

    /**
     * Get VPN statistics
     */
    fun getStats(): Map<String, Any> {
        return mapOf(
            "bytesSent" to bytesSent,
            "bytesReceived" to bytesReceived
        )
    }

    override fun onDestroy() {
        stopVpn()
        instance = null
        super.onDestroy()
    }

    private fun startVpn(assignedIp: String) {
        Log.i(TAG, "Starting VPN...")
        try {
            // Configure VPN interface with dynamic IP from Gateway
            val builder = Builder()
            builder.setSession("Chakra VPN")
            builder.addAddress(assignedIp, 24)  // Use assigned IP
            builder.addRoute("0.0.0.0", 0)
            builder.addDnsServer("8.8.8.8")
            builder.setMtu(1500)
            builder.setBlocking(true)
            
            // For typical VPN apps we might want to exclude our own app's traffic 
            // to avoid loop, but if we are tunneling everything via WebRTC 
            // (which runs in app), we MUST protect the socket. 
            // VpnService.protect(socket) calls are needed on the Flutter/Dart side 
            // or we exclude the app package. 
            // Excluding app package is safer for simple implementation.
            builder.addDisallowedApplication(packageName)

            mInterface = builder.establish()
            
            if (mInterface != null) {
                mRunning.set(true)
                mThread = Thread { runVpnLoop() }
                mThread?.start()
                Log.i(TAG, "VPN Established with IP: $assignedIp")
            } else {
                Log.e(TAG, "Failed to establish VPN interface: establish() returned null")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting VPN: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun stopVpn() {
        mRunning.set(false)
        try {
            mInterface?.close()
        } catch (e: Exception) {
            // Ignore
        }
        mInterface = null
        mThread = null
        stopSelf()
        Log.i(TAG, "VPN Stopped")
    }

    private var mOutputStream: FileOutputStream? = null

    private fun runVpnLoop() {
        val inputStream = FileInputStream(mInterface!!.fileDescriptor)
        mOutputStream = FileOutputStream(mInterface!!.fileDescriptor)
        val buffer = ByteBuffer.allocate(32767)
        
        while (mRunning.get() && mInterface != null) {
            try {
                // Read from TUN
                val length = inputStream.read(buffer.array())
                if (length > 0) {
                    val packet = ByteArray(length)
                    System.arraycopy(buffer.array(), 0, packet, 0, length)
                    
                    // Send to Flutter
                    PacketProcessor.onPacketReceived(packet)
                    bytesReceived += length
                }
                buffer.clear()
            } catch (e: Exception) {
                if (mRunning.get()) {
                    Log.e(TAG, "Error in VPN loop: ${e.message}")
                }
            }
        }
    }

    // Called from Flutter (via MainActivity -> PacketProcessor)
    fun writePacket(packet: ByteArray) {
        if (mInterface != null && mRunning.get() && mOutputStream != null) {
            try {
                mOutputStream?.write(packet)
                bytesSent += packet.size
            } catch (e: Exception) {
                Log.e(TAG, "Error writing packet: ${e.message}")
            }
        }
    }
}
