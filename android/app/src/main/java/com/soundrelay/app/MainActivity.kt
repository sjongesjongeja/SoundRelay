package com.soundrelay.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private lateinit var tvStatusBadge: TextView
    private lateinit var tvDiscoveredPc: TextView
    private lateinit var btnScan: Button
    private lateinit var btnUseDiscovered: Button
    private lateinit var etIpAddress: EditText
    private lateinit var etPort: EditText
    private lateinit var rgSource: RadioGroup
    private lateinit var rbInternal: RadioButton
    private lateinit var btnToggleStream: Button

    private lateinit var discoveryManager: DiscoveryManager
    private var discoveredServer: DiscoveredServer? = null

    private val mediaProjectionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == RESULT_OK && result.data != null) {
            val ip = etIpAddress.text.toString().trim()
            val port = etPort.text.toString().trim().toIntOrNull() ?: 59102

            val intent = Intent(this, AudioCaptureService::class.java).apply {
                action = AudioCaptureService.ACTION_START
                putExtra(AudioCaptureService.EXTRA_RESULT_CODE, result.resultCode)
                putExtra(AudioCaptureService.EXTRA_RESULT_DATA, result.data)
                putExtra(AudioCaptureService.EXTRA_IP, ip)
                putExtra(AudioCaptureService.EXTRA_PORT, port)
                putExtra(AudioCaptureService.EXTRA_IS_MIC, false)
            }
            ContextCompat.startForegroundService(this, intent)
            updateUiState(true)
        } else {
            Toast.makeText(this, "Toestemming voor scherm-/audiocapture geweigerd", Toast.LENGTH_SHORT).show()
            updateUiState(false)
        }
    }

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val recordAudioGranted = permissions[Manifest.permission.RECORD_AUDIO] ?: false
        if (!recordAudioGranted) {
            Toast.makeText(this, "Microfoon/Audio opname permissie vereist", Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        tvStatusBadge = findViewById(R.id.tv_status_badge)
        tvDiscoveredPc = findViewById(R.id.tv_discovered_pc)
        btnScan = findViewById(R.id.btn_scan)
        btnUseDiscovered = findViewById(R.id.btn_use_discovered)
        etIpAddress = findViewById(R.id.et_ip_address)
        etPort = findViewById(R.id.et_port)
        rgSource = findViewById(R.id.rg_source)
        rbInternal = findViewById(R.id.rb_internal)
        btnToggleStream = findViewById(R.id.btn_toggle_stream)

        discoveryManager = DiscoveryManager(this)

        checkPermissions()
        startDiscovery()

        btnScan.setOnClickListener {
            startDiscovery()
        }

        btnUseDiscovered.setOnClickListener {
            discoveredServer?.let {
                etIpAddress.setText(it.ip)
                etPort.setText(it.audioPort.toString())
                Toast.makeText(this, "Geselecteerd: ${it.name} (${it.ip})", Toast.LENGTH_SHORT).show()
            }
        }

        btnToggleStream.setOnClickListener {
            if (AudioCaptureService.isRunning) {
                stopStream()
            } else {
                startStream()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        updateUiState(AudioCaptureService.isRunning)
    }

    private fun checkPermissions() {
        val permissions = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        val needed = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (needed.isNotEmpty()) {
            permissionLauncher.launch(needed.toTypedArray())
        }
    }

    private fun startDiscovery() {
        tvDiscoveredPc.text = "Zoeken naar PC op Wi-Fi..."
        btnUseDiscovered.visibility = View.GONE

        lifecycleScope.launch {
            val server = discoveryManager.discoverServer()
            if (server != null) {
                discoveredServer = server
                tvDiscoveredPc.text = "Gevonden: ${server.name} (${server.ip})"
                btnUseDiscovered.visibility = View.VISIBLE
                if (etIpAddress.text.isNullOrEmpty()) {
                    etIpAddress.setText(server.ip)
                    etPort.setText(server.audioPort.toString())
                }
            } else {
                tvDiscoveredPc.text = "Geen PC automatisch gevonden (controleer of SoundRelay op PC draait)."
            }
        }
    }

    private fun startStream() {
        val ip = etIpAddress.text.toString().trim()
        if (ip.isEmpty()) {
            Toast.makeText(this, "Vul eerst een PC IP-adres in", Toast.LENGTH_SHORT).show()
            return
        }

        val isMic = !rbInternal.isChecked

        if (isMic) {
            val port = etPort.text.toString().trim().toIntOrNull() ?: 59102
            val intent = Intent(this, AudioCaptureService::class.java).apply {
                action = AudioCaptureService.ACTION_START
                putExtra(AudioCaptureService.EXTRA_IP, ip)
                putExtra(AudioCaptureService.EXTRA_PORT, port)
                putExtra(AudioCaptureService.EXTRA_IS_MIC, true)
            }
            ContextCompat.startForegroundService(this, intent)
            updateUiState(true)
        } else {
            val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjectionLauncher.launch(projectionManager.createScreenCaptureIntent())
        }
    }

    private fun stopStream() {
        val intent = Intent(this, AudioCaptureService::class.java).apply {
            action = AudioCaptureService.ACTION_STOP
        }
        startService(intent)
        updateUiState(false)
    }

    private fun updateUiState(running: Boolean) {
        if (running) {
            btnToggleStream.text = "Stop Audio Stream"
            btnToggleStream.setBackgroundColor(ContextCompat.getColor(this, R.color.danger))
            tvStatusBadge.text = "● Streamt Live"
            tvStatusBadge.setTextColor(ContextCompat.getColor(this, R.color.primary))
        } else {
            btnToggleStream.text = "Start Audio Stream"
            btnToggleStream.setBackgroundColor(ContextCompat.getColor(this, R.color.primary))
            tvStatusBadge.text = "Niet verbonden"
            tvStatusBadge.setTextColor(ContextCompat.getColor(this, R.color.text_muted))
        }
    }
}
