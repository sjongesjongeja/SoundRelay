package com.soundrelay.app

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.io.OutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.Socket
import java.nio.ByteBuffer
import java.nio.ByteOrder

class AudioCaptureService : Service() {

    companion object {
        const val ACTION_START = "com.soundrelay.app.START"
        const val ACTION_STOP = "com.soundrelay.app.STOP"
        const val EXTRA_RESULT_CODE = "extra_result_code"
        const val EXTRA_RESULT_DATA = "extra_result_data"
        const val EXTRA_IP = "extra_ip"
        const val EXTRA_PORT = "extra_port"
        const val EXTRA_IS_MIC = "extra_is_mic"

        const val CHANNEL_ID = "soundrelay_capture_channel"
        const val NOTIFICATION_ID = 1001

        const val SAMPLE_RATE = 48000
        const val CHANNELS = AudioFormat.CHANNEL_IN_STEREO
        const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
        // 240 frames = 5ms at 48kHz stereo 16-bit = 960 bytes
        const val CHUNK_FRAMES = 240
        const val CHUNK_BYTES = CHUNK_FRAMES * 4

        @Volatile
        var isRunning = false
    }

    private var mediaProjection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY

        if (action == ACTION_STOP) {
            stopCapture()
            stopSelf()
            return START_NOT_STICKY
        }

        if (action == ACTION_START && !isRunning) {
            val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
            val resultData: Intent? = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(EXTRA_RESULT_DATA)
            }
            val ip = intent.getStringExtra(EXTRA_IP) ?: "127.0.0.1"
            val port = intent.getIntExtra(EXTRA_PORT, 59102)
            val isMic = intent.getBooleanExtra(EXTRA_IS_MIC, false)

            startForegroundServiceNotification(ip)
            acquireLocks()

            isRunning = true

            captureThread = Thread({
                runAudioStreaming(resultCode, resultData, ip, port, isMic)
            }, "SoundRelay-StreamThread")
            captureThread?.start()
        }

        return START_NOT_STICKY
    }

    private fun startForegroundServiceNotification(targetIp: String) {
        val stopIntent = Intent(this, AudioCaptureService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val mainActivityIntent = Intent(this, MainActivity::class.java)
        val mainPendingIntent = PendingIntent.getActivity(
            this, 0, mainActivityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SoundRelay is actief")
            .setContentText("Geluid wordt gestreamd naar PC ($targetIp)...")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentIntent(mainPendingIntent)
            .addAction(android.R.drawable.ic_media_pause, "Stoppen", stopPendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val serviceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            }
            startForeground(NOTIFICATION_ID, notification, serviceType)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SoundRelay Streaming Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Status van actieve audio streaming naar PC"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun acquireLocks() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SoundRelay::WakeLock").apply {
                acquire(12 * 60 * 60 * 1000L) // 12 hours
            }

            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiLock = wifiManager.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "SoundRelay::WifiLock").apply {
                acquire()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    @SuppressLint("MissingPermission")
    private fun runAudioStreaming(
        resultCode: Int,
        resultData: Intent?,
        ip: String,
        port: Int,
        isMic: Boolean
    ) {
        val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNELS, ENCODING)
        val bufferSize = maxOf(minBufferSize, CHUNK_BYTES * 8)

        try {
            if (!isMic) {
                if (resultData == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    stopCapture()
                    return
                }
                val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                mediaProjection = projectionManager.getMediaProjection(resultCode, resultData)
                if (mediaProjection == null) {
                    stopCapture()
                    return
                }

                val captureConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
                    .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                    .addMatchingUsage(AudioAttributes.USAGE_GAME)
                    .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                    .build()

                audioRecord = AudioRecord.Builder()
                    .setAudioPlaybackCaptureConfig(captureConfig)
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(ENCODING)
                            .setSampleRate(SAMPLE_RATE)
                            .setChannelMask(CHANNELS)
                            .build()
                    )
                    .setBufferSizeInBytes(bufferSize)
                    .build()
            } else {
                audioRecord = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    SAMPLE_RATE,
                    CHANNELS,
                    ENCODING,
                    bufferSize
                )
            }

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                stopCapture()
                return
            }

            audioRecord?.startRecording()

            val isUsbTcp = (ip == "127.0.0.1" || ip == "localhost")
            if (isUsbTcp) {
                streamOverTcp(ip, port)
            } else {
                streamOverUdp(ip, port)
            }

        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            stopCapture()
        }
    }

    private fun streamOverUdp(ip: String, port: Int) {
        var socket: DatagramSocket? = null
        try {
            socket = DatagramSocket()
            socket.sendBufferSize = 1024 * 512
            val targetAddress = InetAddress.getByName(ip)

            val pcmBuffer = ByteArray(CHUNK_BYTES)
            val packetBuffer = ByteBuffer.allocate(12 + CHUNK_BYTES)
            packetBuffer.order(ByteOrder.BIG_ENDIAN)

            var seq = 0
            val startTime = System.currentTimeMillis()

            while (isRunning) {
                val bytesRead = audioRecord?.read(pcmBuffer, 0, CHUNK_BYTES) ?: -1
                if (bytesRead > 0) {
                    val timestamp = (System.currentTimeMillis() - startTime).toInt()
                    packetBuffer.clear()
                    packetBuffer.put('S'.code.toByte())
                    packetBuffer.put('R'.code.toByte())
                    packetBuffer.put('L'.code.toByte())
                    packetBuffer.put('Y'.code.toByte())
                    packetBuffer.putInt(seq++)
                    packetBuffer.putInt(timestamp)
                    packetBuffer.put(pcmBuffer, 0, bytesRead)

                    val packet = DatagramPacket(
                        packetBuffer.array(),
                        packetBuffer.position(),
                        targetAddress,
                        port
                    )
                    socket.send(packet)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            socket?.close()
        }
    }

    private fun streamOverTcp(ip: String, port: Int) {
        var socket: Socket? = null
        var outStream: OutputStream? = null
        try {
            socket = Socket(ip, port)
            socket.tcpNoDelay = true
            socket.sendBufferSize = 1024 * 512
            outStream = socket.getOutputStream()

            val pcmBuffer = ByteArray(CHUNK_BYTES)
            val packetBuffer = ByteBuffer.allocate(12 + CHUNK_BYTES)
            packetBuffer.order(ByteOrder.BIG_ENDIAN)

            var seq = 0
            val startTime = System.currentTimeMillis()

            while (isRunning) {
                val bytesRead = audioRecord?.read(pcmBuffer, 0, CHUNK_BYTES) ?: -1
                if (bytesRead > 0) {
                    val timestamp = (System.currentTimeMillis() - startTime).toInt()
                    packetBuffer.clear()
                    packetBuffer.put('S'.code.toByte())
                    packetBuffer.put('R'.code.toByte())
                    packetBuffer.put('L'.code.toByte())
                    packetBuffer.put('Y'.code.toByte())
                    packetBuffer.putInt(seq++)
                    packetBuffer.putInt(timestamp)
                    packetBuffer.put(pcmBuffer, 0, bytesRead)

                    outStream.write(packetBuffer.array(), 0, packetBuffer.position())
                    outStream.flush()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            try { outStream?.close() } catch (ignored: Exception) {}
            try { socket?.close() } catch (ignored: Exception) {}
        }
    }

    private fun stopCapture() {
        isRunning = false
        try {
            if (audioRecord?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                audioRecord?.stop()
            }
            audioRecord?.release()
            audioRecord = null
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            mediaProjection?.stop()
            mediaProjection = null
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
            if (wifiLock?.isHeld == true) wifiLock?.release()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    override fun onDestroy() {
        stopCapture()
        super.onDestroy()
    }
}
