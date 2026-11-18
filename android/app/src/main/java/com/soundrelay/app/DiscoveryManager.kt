package com.soundrelay.app

import android.content.Context
import android.net.DhcpInfo
import android.net.wifi.WifiManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

data class DiscoveredServer(
    val name: String,
    val ip: String,
    val audioPort: Int,
    val webPort: Int
)

class DiscoveryManager(private val context: Context) {

    suspend fun discoverServer(timeoutMs: Int = 2500): DiscoveredServer? = withContext(Dispatchers.IO) {
        var socket: DatagramSocket? = null
        try {
            socket = DatagramSocket()
            socket.broadcast = true
            socket.soTimeout = timeoutMs

            val broadcastAddr = getBroadcastAddress()
            val msg = "SOUNDRELAY_DISCOVER".toByteArray()
            val packet = DatagramPacket(msg, msg.size, broadcastAddr, 59101)
            socket.send(packet)

            val buf = ByteArray(1024)
            val recvPacket = DatagramPacket(buf, buf.size)
            socket.receive(recvPacket)

            val reply = String(recvPacket.data, 0, recvPacket.length).trim()
            if (reply.startsWith("SOUNDRELAY_OFFER:")) {
                val parts = reply.split(":")
                if (parts.size >= 5) {
                    val name = parts[1]
                    val ip = parts[2]
                    val audioPort = parts[3].toIntOrNull() ?: 59102
                    val webPort = parts[4].toIntOrNull() ?: 59100
                    return@withContext DiscoveredServer(name, ip, audioPort, webPort)
                }
            }
        } catch (e: Exception) {
            // Timeout or network unreachable
        } finally {
            socket?.close()
        }
        return@withContext null
    }

    private fun getBroadcastAddress(): InetAddress {
        try {
            val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val dhcp: DhcpInfo = wifi.dhcpInfo
            val broadcast = (dhcp.ipAddress and dhcp.netmask) or dhcp.netmask.inv()
            val quads = ByteArray(4)
            for (k in 0..3) {
                quads[k] = ((broadcast shr (k * 8)) and 0xFF).toByte()
            }
            return InetAddress.getByAddress(quads)
        } catch (e: Exception) {
            return InetAddress.getByName("255.255.255.255")
        }
    }
}
