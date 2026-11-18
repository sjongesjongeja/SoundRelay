# SoundRelay - Audio van je Telefoon op je PC afspelen

SoundRelay is een open-source alternatief voor AudioRelay waarmee je het geluid van je smartphone (Android of iOS) in real-time, in hoge kwaliteit en met extreem lage latentie op je Windows-pc kunt afspelen.

---

## 🚀 Snelstart (In 3 Stappen)

### 1. Start de PC Receiver
Dubbelklik op:
```bat
Start-SoundRelay.bat
```
*(Of voer `server\start_receiver.bat` uit).*  
Het dashboard opent direct in je browser op **`http://localhost:59100`**.

### 2. Geluid streamen vanaf je telefoon

Er zijn **3 manieren** om te streamen:

#### Optie A: Android App (Volledig Systeemgeluid / AudioRelay stijl) ⭐ *Aanbevolen voor Android*
1. Installeer het APK-bestand op je Android-toestel:  
   👉 `bin\SoundRelay.apk` (of bouw opnieuw via `Build-APK.bat`).
2. Open **SoundRelay** op je telefoon.
3. De app zoekt automatisch naar je PC op het Wi-Fi-netwerk. Tik op **"Verbind met deze PC"** (of typ het IP-adres in).
4. Kies **Systeemgeluid** (voor Spotify, YouTube, games, TikTok, etc.) of **Microfoon**.
5. Tik op **"Start Audio Stream"** en geef eenmalig toestemming.  
   Het geluid speelt direct af via de luidsprekers of hoofdtelefoon van je PC!

#### Optie B: Mobiele Web Streamer (Geen installatie nodig - Werkt ook op iPhone!)
1. Open de mobiele browser op je telefoon (Safari of Chrome).
2. Ga naar: `http://<JOUW-PC-IP>:59100/mic` (of scan de QR-code op het PC-dashboard).
3. Tik op **"Start Streaming"** en geef toegang tot je microfoon.
4. Geluid streamt direct over WebSockets naar je PC.

#### Optie C: USB Kabel Modus (0ms Latentie - Perfect voor Gamen & Video's)
1. Sluit je Android telefoon met een USB-kabel aan op je PC.
2. Zorg dat *USB-foutopsporing* (USB Debugging) aan staat in de ontwikkelaarsopties van je telefoon.
3. Voer op je PC uit:
   ```bat
   server\usb_stream.bat
   ```
4. Vul in de SoundRelay Android-app als IP-adres in:
   ```
   127.0.0.1
   ```
5. Tik op **Start Audio Stream**. De audio gaat nu met sub-5ms latentie direct door de kabel!

---

## 🎛️ PC Dashboard Features (`http://localhost:59100`)

- **Live VU Meter & Visualizer:** Zie direct of er audio binnenkomt en op welk volume.
- **Uitvoerapparaat kiezen:** Wissel direct tussen Speakers, Headset, Realtek of virtuele audio-apparaten zonder herstart.
- **Volume & Boost:** Regel het volume tot 200% versterking.
- **Buffer Modus:**
  - *Ultra Low (15ms):* Minimale vertraging voor gaming en video's.
  - *Standaard (30ms):* Optimale balans voor normaal Wi-Fi-gebruik.
  - *Stabiel (60ms):* Voor drukke of instabiele Wi-Fi-netwerken.
- **Automatische Auto-Discovery:** Telefoon vindt PC automatisch via UDP-broadcasts.

---

## 🛠️ Projectstructuur

```
f:\audiorelay\
├── server\                     # PC Receiver Backend & Web UI
│   ├── receiver.py             # Audio engine, WASAPI output, UDP/TCP receiver & auto-discovery
│   ├── web_server.py           # FastAPI + WebSocket server
│   ├── run.py                  # Hoofd-opstartscript
│   ├── static\                 # Web dashboard & mobiele streamer
│   ├── requirements.txt        # Python libraries
│   ├── start_receiver.bat      # 1-klik PC launcher
│   └── usb_stream.bat          # 1-klik ADB USB-tunnel setup
├── android\                    # Volledige Android Studio / Gradle broncode
│   └── app\src\main\java\com\soundrelay\app\
│       ├── MainActivity.kt     # UI, permissies & server discovery
│       ├── AudioCaptureService.kt # Foreground service & AudioPlaybackCapture
│       └── DiscoveryManager.kt # UDP discovery client
├── bin\
│   └── SoundRelay.apk          # Kant-en-klare Android applicatie
├── Start-SoundRelay.bat        # Hoofdmenu
├── Build-APK.bat               # Automatisch hercompileren van de APK
└── README.md
```

---

## ⚙️ Technische Specificaties

- **Audio Formaat:** PCM 16-bit, 48.000 Hz, Stereo (Studio kwaliteit)
- **Transport:** UDP (Wi-Fi) met SRLY sequence headers en adaptive jitter buffer / TCP over ADB (USB)
- **Android API:** `AudioPlaybackCaptureConfiguration` (Android 10+ / API 29+) met `MediaProjection`
- **PC Audio Driver:** Windows WASAPI / DirectSound via `sounddevice`
