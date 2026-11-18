# SoundRelay - Audio van je Telefoon op je Laptop / PC afspelen

SoundRelay is een open-source alternatief voor AudioRelay waarmee je het geluid van je smartphone (Android of iOS) in real-time, in hoge kwaliteit en met extreem lage latentie op je Windows-laptop of pc kunt afspelen.

---

## ⚡ Installatie op je Laptop (Windows .exe)

Je hoeft geen Python of ingewikkelde tools te installeren. We hebben een kant-en-klaar installatieprogramma gebouwd:

👉 **[Download / Voer uit: bin\SoundRelay-Setup.exe](bin/SoundRelay-Setup.exe)** (29 MB)

1. Voer **`SoundRelay-Setup.exe`** uit op je laptop.
2. Volg de installatiewizard. Deze maakt automatisch:
   - Een snelkoppeling op je **Bureaublad**.
   - Een vermelding in je **Startmenu**.
   - Een nette uninstaller in Windows Instellingen.
3. Na de installatie start SoundRelay direct op en opent je browser automatisch op `http://localhost:59100`.

---

## 📲 APK Downloaden via QR-Code op het Web Dashboard

Wanneer SoundRelay op je laptop draait, toont het Web Dashboard direct een interactieve **QR-code**:

1. Open het dashboard op je laptop: **`http://localhost:59100`**.
2. Richt de camera van je telefoon op de **QR-code** op het scherm.
3. Je telefoon downloadt `SoundRelay.apk` direct vanaf je laptop over het lokale Wi-Fi-netwerk!
4. Tik op **Installeren** en open de app.
5. De app vindt je laptop automatisch via Wi-Fi; tik op **"Start Audio Stream"**.

*(Alternatief: Je kunt ook op de laptop direct klikken op `⬇️ Download SoundRelay.apk` of het bestand vinden in `bin\SoundRelay.apk`).*

---

## 🚀 Verbinden: 3 Verschillende Manieren

### 1. Android App (Volledig Systeemgeluid) ⭐ *Beste ervaring*
- Vangt intern alle audio op (Spotify, YouTube, TikTok, games, Netflix, browser).
- Werkt op de achtergrond en met het telefoonscherm uitgeschakeld.
- Auto-discovery via Wi-Fi (geen IP-adressen intypen).

### 2. USB Kabel (0ms Latentie voor Gaming & Video)
1. Sluit je telefoon aan via een USB-kabel en zet *USB-foutopsporing* (USB Debugging) aan.
2. Klik in het Startmenu op **SoundRelay USB Modus** (of voer `server\usb_stream.bat` uit).
3. Vul in de Android app als IP `127.0.0.1` in. Audio loopt nu direct door de kabel met minder dan 5ms vertraging!

### 3. Zonder app via de Browser (iOS / iPhone & Android)
- Scan de Web Streamer QR-code op het dashboard of ga naar `http://<PC-IP>:59100/mic`.
- Stream direct de audio/microfoon van je telefoon naar de laptop via WebSockets.

---

## 🎛️ PC Dashboard Functionaliteiten (`http://localhost:59100`)

- **Live VU Meter & Visualizer:** Real-time piekmeting per kanaal (L/R) en geanimeerde spectrum visualizer.
- **Audio-uitvoer kiezen:** Wissel direct tussen je laptopspeakers, externe monitor, hoofdtelefoon of Bluetooth headset.
- **Volume & Boost:** Tot 200% volumeversterking.
- **Bufferprofielen:** Ultra Low (15ms), Standaard (30ms), of Wi-Fi Stabiel (60ms).

---

## 🐙 Project op GitHub zetten

Dit project is al volledig voorbereid als Git repository inclusief `.gitignore` en automatische **GitHub Actions CI/CD workflows**.

### Optie 1: Automatisch via het script
Voer uit:
```bat
Push-To-GitHub.bat
```
Het script gebruikt de geïnstalleerde GitHub CLI om in te loggen en de repository automatisch voor je aan te maken en te pushen.

### Optie 2: Handmatig
1. Maak een nieuwe repository aan op: [github.com/new](https://github.com/new) (bijvoorbeeld `audiorelay`).
2. Voer deze commando's uit in de terminal:
```bash
git remote add origin https://github.com/sjongesjongeja/audiorelay.git
git push -u origin main
```

Elke push of release-tag (`v1.0.0`) bouwt automatisch zowel de Android APK als de Windows installer via GitHub Actions!

---

## 📁 Bestandsstructuur

```
f:\audiorelay\
├── bin\
│   ├── SoundRelay-Setup.exe    # Windows Installer (Laptop installatiebestand)
│   └── SoundRelay.apk          # Android App installatiebestand
├── server\                     # PC Receiver Backend & Web UI
│   ├── receiver.py             # Audio engine (WASAPI), UDP/TCP receiver & discovery
│   ├── web_server.py           # FastAPI + WebSocket server + APK download server
│   ├── run.py                  # Hoofdprogramma met automatische browser-opener
│   ├── static\                 # Dashboard met QR-codes & live visualizer
│   ├── start_receiver.bat      # Handmatige PC receiver launcher
│   └── usb_stream.bat          # ADB USB tunnel
├── android\                    # Android Studio broncode (Kotlin)
│   └── app\src\main\java\com\soundrelay\app\
│       ├── MainActivity.kt
│       ├── AudioCaptureService.kt
│       └── DiscoveryManager.kt
├── installer\
│   └── SoundRelay.iss          # Inno Setup configuratiescript
├── .github\workflows\
│   └── build.yml               # GitHub Actions CI/CD pipeline
├── Start-SoundRelay.bat        # Hoofdmenu
├── Build-Installer.bat         # Rebuild Windows Setup .exe
├── Build-APK.bat               # Rebuild Android APK
├── Push-To-GitHub.bat          # 1-klik GitHub upload
└── README.md
```
