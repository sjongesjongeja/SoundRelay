// SoundRelay Dashboard Frontend
let ws = null;
let currentPrimaryIp = "127.0.0.1";
const canvas = document.getElementById("visualizer-canvas");
const ctx = canvas.getContext("2d");
let visualizerData = new Array(32).fill(0);

// Initialize visualizer canvas
function resizeCanvas() {
    canvas.width = canvas.parentElement.clientWidth;
    canvas.height = 60;
}
window.addEventListener("resize", resizeCanvas);
resizeCanvas();

function drawVisualizer() {
    requestAnimationFrame(drawVisualizer);
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    const barWidth = (canvas.width / visualizerData.length) - 2;
    for (let i = 0; i < visualizerData.length; i++) {
        const h = visualizerData[i] * canvas.height;
        const x = i * (barWidth + 2);
        const y = canvas.height - h;

        const grad = ctx.createLinearGradient(0, canvas.height, 0, 0);
        grad.addColorStop(0, "#10b981");
        grad.addColorStop(0.7, "#06b6d4");
        grad.addColorStop(1, "#ef4444");

        ctx.fillStyle = grad;
        ctx.fillRect(x, y, barWidth, h);
    }
}
drawVisualizer();

// Connect status WebSocket for real-time VU meter
function connectStatusWS() {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const wsUrl = `${protocol}//${window.location.host}/ws/status`;
    ws = new WebSocket(wsUrl);

    ws.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            updateUI(data);
        } catch (e) {
            console.error("Status parse error:", e);
        }
    };

    ws.onclose = () => {
        setTimeout(connectStatusWS, 1500);
    };

    ws.onerror = () => {
        ws.close();
    };
}

function updateUI(status) {
    // Meters
    const meterLeft = document.getElementById("meter-left");
    const meterRight = document.getElementById("meter-right");
    const peakL = Math.min(100, Math.round(status.peak_left * 100));
    const peakR = Math.min(100, Math.round(status.peak_right * 100));
    meterLeft.style.width = `${peakL}%`;
    meterRight.style.width = `${peakR}%`;

    // Visualizer simulation values based on peak
    const avgPeak = (status.peak_left + status.peak_right) / 2;
    for (let i = 0; i < visualizerData.length; i++) {
        const factor = Math.sin((i / visualizerData.length) * Math.PI) * (0.5 + Math.random() * 0.5);
        const target = Math.min(1.0, avgPeak * factor * 1.3);
        visualizerData[i] = visualizerData[i] * 0.7 + target * 0.3;
    }

    // Badge & Client
    const badge = document.getElementById("conn-badge");
    const badgeText = document.getElementById("conn-badge-text");
    const statClient = document.getElementById("stat-client");

    if (status.connected) {
        badge.className = "badge online";
        badgeText.textContent = "Verbonden & Ontvangen";
        statClient.textContent = status.client_ip || "Actief";
    } else {
        badge.className = "badge offline";
        badgeText.textContent = "Wachten op verbinding...";
        statClient.textContent = "Geen";
    }

    // Stats
    document.getElementById("bitrate-tag").textContent = `${status.bitrate_kbps} kbps`;
    document.getElementById("stat-latency").textContent = `${status.buffered_ms} ms (Doel: ${status.target_latency_ms} ms)`;
    document.getElementById("stat-packets").textContent = status.packets_received.toLocaleString();
    document.getElementById("stat-lost").textContent = status.lost_packets.toLocaleString();
}

// Load devices and IP list
async function loadInitialData() {
    try {
        const res = await fetch("/api/status");
        const data = await res.json();
        
        // IPs
        const ipContainer = document.getElementById("ip-list");
        ipContainer.innerHTML = "";
        if (data.ips && data.ips.length > 0) {
            currentPrimaryIp = data.ips[0];
            data.ips.forEach(ip => {
                const chip = document.createElement("span");
                chip.className = "ip-chip";
                chip.textContent = `${ip}:59102`;
                ipContainer.appendChild(chip);
            });
        }

        // Render QR Codes
        if (window.QRCode) {
            const qrApkCanvas = document.getElementById("qr-apk");
            const apkUrl = `http://${currentPrimaryIp}:59100/download/SoundRelay.apk`;
            if (qrApkCanvas) {
                QRCode.toCanvas(qrApkCanvas, apkUrl, { width: 135, margin: 1 }, (err) => {
                    if (err) console.error("QR APK error:", err);
                });
            }

            const qrIpaCanvas = document.getElementById("qr-ipa");
            const ipaUrl = `http://${currentPrimaryIp}:59100/download/SoundRelay.ipa`;
            if (qrIpaCanvas) {
                QRCode.toCanvas(qrIpaCanvas, ipaUrl, { width: 135, margin: 1 }, (err) => {
                    if (err) console.error("QR IPA error:", err);
                });
            }

            const qrWebmicCanvas = document.getElementById("qr-webmic");
            const webmicUrl = `http://${currentPrimaryIp}:59100/mic`;
            if (qrWebmicCanvas) {
                QRCode.toCanvas(qrWebmicCanvas, webmicUrl, { width: 135, margin: 1 }, (err) => {
                    if (err) console.error("QR Webmic error:", err);
                });
            }
        }

        // Tab switching between APK, IPA, and WebMic
        const tabApk = document.getElementById("tab-apk");
        const tabIpa = document.getElementById("tab-ipa");
        const tabWebmic = document.getElementById("tab-webmic");
        const secApk = document.getElementById("section-apk");
        const secIpa = document.getElementById("section-ipa");
        const secWebmic = document.getElementById("section-webmic");

        function switchTab(activeTab, activeSec) {
            [tabApk, tabIpa, tabWebmic].forEach(t => { if (t) t.classList.remove("active"); });
            [secApk, secIpa, secWebmic].forEach(s => { if (s) s.style.display = "none"; });
            if (activeTab) activeTab.classList.add("active");
            if (activeSec) activeSec.style.display = "flex";
        }

        if (tabApk) tabApk.addEventListener("click", () => switchTab(tabApk, secApk));
        if (tabIpa) tabIpa.addEventListener("click", () => switchTab(tabIpa, secIpa));
        if (tabWebmic) tabWebmic.addEventListener("click", () => switchTab(tabWebmic, secWebmic));

        // Volume
        if (data.volume !== undefined) {
            document.getElementById("volume-slider").value = data.volume;
            document.getElementById("volume-val").textContent = `${Math.round(data.volume * 100)}%`;
        }

        // Output devices
        const devRes = await fetch("/api/devices");
        const devices = await devRes.json();
        const select = document.getElementById("device-select");
        select.innerHTML = "";
        
        devices.forEach(dev => {
            const opt = document.createElement("option");
            opt.value = dev.id;
            opt.textContent = `[${dev.hostapi}] ${dev.name}`;
            if (dev.id === data.current_device || (data.current_device === null && dev.default)) {
                opt.selected = true;
            }
            select.appendChild(opt);
        });

    } catch (e) {
        console.error("Failed to load initial data:", e);
    }
}

// Device selector change
document.getElementById("device-select").addEventListener("change", async (e) => {
    const devId = parseInt(e.target.value);
    await fetch("/api/device", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ device_id: devId })
    });
});

// Volume slider
document.getElementById("volume-slider").addEventListener("input", async (e) => {
    const vol = parseFloat(e.target.value);
    document.getElementById("volume-val").textContent = `${Math.round(vol * 100)}%`;
    await fetch("/api/volume", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ volume: vol })
    });
});

// Latency chip buttons
document.querySelectorAll(".btn-chip").forEach(btn => {
    btn.addEventListener("click", async () => {
        document.querySelectorAll(".btn-chip").forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        const lat = parseFloat(btn.dataset.latency);
        await fetch("/api/latency", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ latency_ms: lat })
        });
    });
});

// Start
loadInitialData();
connectStatusWS();
