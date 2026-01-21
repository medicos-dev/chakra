package com.example.chakra

import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CONTROL_CHANNEL = "com.chakra.vpn/control"
    private val PACKET_CHANNEL = "com.chakra.vpn/packets"
    private val VPN_REQUEST_CODE = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Control Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val ip = call.argument<String>("ip") ?: "10.0.0.2"
                    startVpn(ip)
                    result.success(true)
                }
                "stop" -> {
                    val intent = Intent(this, ChakraVpnService::class.java)
                    intent.action = "STOP"
                    startService(intent)
                    result.success(true)
                }
                "write" -> {
                    val packet = call.argument<ByteArray>("packet")
                    if (packet != null) {
                        PacketProcessor.writePacket(packet)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Packet data is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Packet Stream Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PACKET_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    PacketProcessor.registerSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    PacketProcessor.registerSink(null)
                }
            }
        )
    }

    private var pendingIp: String = "10.0.0.2"

    private fun startVpn(ip: String) {
        pendingIp = ip
        val intent = VpnService.prepare(this)
        if (intent != null) {
            startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            onActivityResult(VPN_REQUEST_CODE, RESULT_OK, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE && resultCode == RESULT_OK) {
            val intent = Intent(this, ChakraVpnService::class.java)
            intent.putExtra("assigned_ip", pendingIp)  // Key must match Kotlin's getStringExtra
            startService(intent)
        }
    }
}
