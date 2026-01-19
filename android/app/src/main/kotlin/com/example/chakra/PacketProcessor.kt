package com.example.chakra

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object PacketProcessor {
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    fun registerSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun onPacketReceived(packet: ByteArray) {
        // Must send on Main Thread for EventChannel
        handler.post {
            eventSink?.success(packet)
        }
    }

    fun writePacket(packet: ByteArray) {
        // Send to Service
        ChakraVpnService.instance?.writePacket(packet)
    }
}
