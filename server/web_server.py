import asyncio
import json
import socket
import sys
import os
from typing import Optional
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel
import os

try:
    from receiver import AudioEngine, AudioReceiverServer
except ImportError:
    from server.receiver import AudioEngine, AudioReceiverServer

app = FastAPI(title="SoundRelay PC Server")

# Global references (initialized in run.py)
audio_engine: Optional[AudioEngine] = None
receiver_server: Optional[AudioReceiverServer] = None

class VolumeRequest(BaseModel):
    volume: float

class DeviceRequest(BaseModel):
    device_id: int

class LatencyRequest(BaseModel):
    latency_ms: float

def get_all_ips():
    ips = set()
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ips.add(s.getsockname()[0])
        s.close()
    except Exception:
        pass
    try:
        host = socket.gethostname()
        for ip in socket.gethostbyname_ex(host)[2]:
            if not ip.startswith("127."):
                ips.add(ip)
    except Exception:
        pass
    return list(ips) or ["127.0.0.1"]

@app.get("/api/status")
async def get_status():
    if receiver_server is None:
        return JSONResponse({"error": "Server not initialized"}, status_code=500)
    status = receiver_server.get_status()
    status["ips"] = get_all_ips()
    return status

@app.get("/api/devices")
async def get_devices():
    if audio_engine is None:
        return []
    return audio_engine.get_devices()

@app.post("/api/device")
async def set_device(req: DeviceRequest):
    if audio_engine:
        audio_engine.set_device(req.device_id)
        return {"ok": True, "device_id": req.device_id}
    return {"ok": False}

@app.post("/api/volume")
async def set_volume(req: VolumeRequest):
    if audio_engine:
        audio_engine.set_volume(req.volume)
        return {"ok": True, "volume": audio_engine.volume}
    return {"ok": False}

@app.post("/api/latency")
async def set_latency(req: LatencyRequest):
    if audio_engine:
        audio_engine.set_target_latency(req.latency_ms)
        return {"ok": True, "latency_ms": req.latency_ms}
    return {"ok": False}

@app.websocket("/ws/status")
async def status_stream(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            if receiver_server:
                data = receiver_server.get_status()
                await websocket.send_json(data)
            await asyncio.sleep(0.04)  # 25 updates/sec for smooth VU meters
    except WebSocketDisconnect:
        pass
    except Exception:
        pass

@app.websocket("/ws/audio")
async def audio_stream_ws(websocket: WebSocket):
    """Allows Web-based client (like mobile browser mic sender) to stream audio."""
    await websocket.accept()
    client_ip = websocket.client.host if websocket.client else "web-client"
    print(f"[SoundRelay WS] Audio client connected from {client_ip}")
    if receiver_server:
        with receiver_server.stats_lock:
            receiver_server.client_ip = f"Web: {client_ip}"
    try:
        while True:
            # Receives raw binary PCM Int16 stereo data from browser
            data = await websocket.receive_bytes()
            if data and audio_engine:
                audio_engine.push_pcm(data)
                if receiver_server:
                    with receiver_server.stats_lock:
                        receiver_server.bytes_received += len(data)
                        receiver_server.packets_received += 1
                        receiver_server.last_packet_time = asyncio.get_event_loop().time()
    except WebSocketDisconnect:
        print(f"[SoundRelay WS] Audio client disconnected from {client_ip}")
    except Exception as e:
        print(f"[SoundRelay WS] Stream error: {e}")
    finally:
        if receiver_server and receiver_server.client_ip and "Web:" in receiver_server.client_ip:
            receiver_server.client_ip = None

# Mount static files
if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
    static_dir = os.path.join(sys._MEIPASS, "static")
else:
    static_dir = os.path.join(os.path.dirname(__file__), "static")

if not os.path.exists(static_dir):
    os.makedirs(static_dir, exist_ok=True)

def get_apk_path():
    candidates = []
    if getattr(sys, 'frozen', False):
        exe_dir = os.path.dirname(sys.executable)
        candidates.extend([
            os.path.join(exe_dir, "bin", "SoundRelay.apk"),
            os.path.join(exe_dir, "SoundRelay.apk"),
            os.path.join(sys._MEIPASS, "bin", "SoundRelay.apk") if hasattr(sys, '_MEIPASS') else ""
        ])
    candidates.extend([
        os.path.join(os.path.dirname(__file__), "..", "bin", "SoundRelay.apk"),
        os.path.join(os.path.dirname(__file__), "SoundRelay.apk"),
        os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "bin", "SoundRelay.apk"),
        os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "SoundRelay.apk"),
        r"f:\audiorelay\bin\SoundRelay.apk"
    ])
    for c in candidates:
        if c and os.path.exists(c):
            return c
    return None

def get_ipa_path():
    candidates = []
    if getattr(sys, 'frozen', False):
        exe_dir = os.path.dirname(sys.executable)
        candidates.extend([
            os.path.join(exe_dir, "bin", "SoundRelay.ipa"),
            os.path.join(exe_dir, "SoundRelay.ipa"),
            os.path.join(sys._MEIPASS, "bin", "SoundRelay.ipa") if hasattr(sys, '_MEIPASS') else ""
        ])
    candidates.extend([
        os.path.join(os.path.dirname(__file__), "..", "bin", "SoundRelay.ipa"),
        os.path.join(os.path.dirname(__file__), "SoundRelay.ipa"),
        os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "bin", "SoundRelay.ipa"),
        os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "SoundRelay.ipa"),
        r"f:\audiorelay\bin\SoundRelay.ipa"
    ])
    for c in candidates:
        if c and os.path.exists(c):
            return c
    return None

@app.get("/download/SoundRelay.apk")
async def download_apk():
    apk_path = get_apk_path()
    if apk_path and os.path.exists(apk_path):
        return FileResponse(
            apk_path,
            media_type="application/vnd.android.package-archive",
            filename="SoundRelay.apk",
            headers={"Content-Disposition": 'attachment; filename="SoundRelay.apk"'}
        )
    return JSONResponse({"error": "SoundRelay.apk is niet gevonden op de server."}, status_code=404)

@app.get("/download/SoundRelay.ipa")
async def download_ipa():
    ipa_path = get_ipa_path()
    if ipa_path and os.path.exists(ipa_path):
        return FileResponse(
            ipa_path,
            media_type="application/octet-stream",
            filename="SoundRelay.ipa",
            headers={"Content-Disposition": 'attachment; filename="SoundRelay.ipa"'}
        )
    return JSONResponse({"error": "SoundRelay.ipa is niet gevonden op de server."}, status_code=404)

@app.get("/")
async def root():
    return FileResponse(os.path.join(static_dir, "index.html"))

@app.get("/mic")
async def mic_page():
    return FileResponse(os.path.join(static_dir, "mic.html"))

app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")
