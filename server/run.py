import sys
import os
import time
import threading
import webbrowser
import uvicorn
try:
    import web_server
    from receiver import AudioEngine, AudioReceiverServer
except ImportError:
    from server import web_server
    from server.receiver import AudioEngine, AudioReceiverServer

def main():
    print("=" * 60)
    print("       SOUNDRELAY - AUDIO RECEIVER FOR WINDOWS       ")
    print("=" * 60)
    
    # 1. Start Audio Engine
    print("[1/3] Initializing Audio Engine (WASAPI / Low-Latency)...")
    engine = AudioEngine(target_latency_ms=25.0)
    web_server.audio_engine = engine

    # 2. Start UDP Audio Receiver and Discovery Service
    print("[2/3] Starting UDP Audio Streamer & Auto-Discovery Service...")
    receiver = AudioReceiverServer(engine)
    receiver.start()
    web_server.receiver_server = receiver

    primary_ip = receiver._get_primary_ip()
    print("[3/3] Starting Web Dashboard & Mobile Web Sender...")
    print(f"      Dashboard:    http://localhost:59100")
    print(f"      LAN Access:   http://{primary_ip}:59100")
    print(f"      APK Download: http://{primary_ip}:59100/download/SoundRelay.apk")
    print(f"      Web Mic Test: http://{primary_ip}:59100/mic")
    print("=" * 60)
    print("Ready to receive audio from your Android phone or Web client!")
    print("Press Ctrl+C to stop.")
    print("=" * 60)

    def _auto_open_browser():
        time.sleep(1.2)
        try:
            webbrowser.open("http://localhost:59100")
        except Exception:
            pass

    threading.Thread(target=_auto_open_browser, daemon=True).start()

    try:
        uvicorn.run(
            web_server.app,
            host="0.0.0.0",
            port=59100,
            log_level="warning"
        )
    except KeyboardInterrupt:
        print("\nStopping SoundRelay...")
    finally:
        receiver.stop()
        print("SoundRelay stopped cleanly.")

if __name__ == "__main__":
    main()
