import socket
import threading
import time
import struct
import numpy as np
import sounddevice as sd
from typing import Optional, List, Dict, Any

MAGIC = b'SRLY'
AUDIO_PORT = 59102
DISCOVERY_PORT = 59101
SAMPLE_RATE = 48000
CHANNELS = 2
BYTES_PER_SAMPLE = 2  # int16
FRAME_SIZE = CHANNELS * BYTES_PER_SAMPLE  # 4 bytes per stereo frame

class JitterBuffer:
    """Adaptive Jitter Buffer for smooth, low-latency audio streaming."""
    def __init__(self, capacity_frames: int = SAMPLE_RATE * 2, target_latency_ms: float = 30.0):
        self.capacity = capacity_frames
        self.buffer = np.zeros((capacity_frames, CHANNELS), dtype=np.int16)
        self.write_idx = 0
        self.read_idx = 0
        self.available_frames = 0
        self.lock = threading.Lock()
        
        self.target_latency_ms = target_latency_ms
        self.target_frames = int(SAMPLE_RATE * (target_latency_ms / 1000.0))
        self.is_buffering = True
        self.underruns = 0
        self.overruns = 0

    def set_target_latency(self, latency_ms: float):
        with self.lock:
            self.target_latency_ms = max(5.0, min(200.0, latency_ms))
            self.target_frames = int(SAMPLE_RATE * (self.target_latency_ms / 1000.0))

    def write(self, pcm_int16_stereo: np.ndarray):
        frames = len(pcm_int16_stereo)
        if frames == 0:
            return

        with self.lock:
            # Overrun check: if incoming audio exceeds capacity or latency target by 3x
            max_tolerable = max(self.target_frames * 3, int(SAMPLE_RATE * 0.12))  # max 120ms
            if self.available_frames > max_tolerable:
                excess = self.available_frames - self.target_frames
                self.read_idx = (self.read_idx + excess) % self.capacity
                self.available_frames -= excess
                self.overruns += 1

            # Circular write
            end_idx = self.write_idx + frames
            if end_idx <= self.capacity:
                self.buffer[self.write_idx:end_idx] = pcm_int16_stereo
            else:
                first_part = self.capacity - self.write_idx
                self.buffer[self.write_idx:] = pcm_int16_stereo[:first_part]
                second_part = frames - first_part
                self.buffer[:second_part] = pcm_int16_stereo[first_part:]
            
            self.write_idx = (self.write_idx + frames) % self.capacity
            self.available_frames += frames

            if self.is_buffering and self.available_frames >= self.target_frames:
                self.is_buffering = False

    def read(self, outdata: np.ndarray, num_frames: int):
        with self.lock:
            if self.is_buffering or self.available_frames < num_frames:
                # Underrun: output silence
                outdata.fill(0)
                self.underruns += 1
                if self.available_frames == 0:
                    self.is_buffering = True
                return

            end_idx = self.read_idx + num_frames
            if end_idx <= self.capacity:
                outdata[:] = self.buffer[self.read_idx:end_idx]
            else:
                first_part = self.capacity - self.read_idx
                outdata[:first_part] = self.buffer[self.read_idx:]
                second_part = num_frames - first_part
                outdata[first_part:] = self.buffer[:second_part]

            self.read_idx = (self.read_idx + num_frames) % self.capacity
            self.available_frames -= num_frames


class AudioEngine:
    def __init__(self, target_latency_ms: float = 30.0):
        self.target_latency_ms = target_latency_ms
        self.jitter_buffer = JitterBuffer(target_latency_ms=target_latency_ms)
        self.volume = 1.0
        self.current_device: Optional[int] = None
        self.stream: Optional[sd.OutputStream] = None
        self.running = False
        
        # Audio level metering
        self.peak_left = 0.0
        self.peak_right = 0.0
        
        self.start_stream()

    def start_stream(self, device_id: Optional[int] = None):
        if self.stream is not None:
            try:
                self.stream.stop()
                self.stream.close()
            except Exception:
                pass
            self.stream = None

        self.current_device = device_id
        
        def audio_callback(outdata, frames, time_info, status):
            self.jitter_buffer.read(outdata, frames)
            if self.volume != 1.0:
                outdata[:] = np.clip(outdata.astype(np.float32) * self.volume, -32768, 32767).astype(np.int16)
            
            # Update meter (peak estimation)
            if frames > 0:
                abs_data = np.abs(outdata)
                self.peak_left = float(np.max(abs_data[:, 0])) / 32768.0
                self.peak_right = float(np.max(abs_data[:, 1])) / 32768.0

        try:
            self.stream = sd.OutputStream(
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                dtype='int16',
                blocksize=256,
                latency='low',
                device=device_id,
                callback=audio_callback
            )
            self.stream.start()
            self.running = True
        except Exception as e:
            print(f"[AudioEngine] Error opening output stream: {e}")
            self.running = False

    def set_volume(self, volume: float):
        self.volume = max(0.0, min(2.5, volume))

    def set_target_latency(self, latency_ms: float):
        self.target_latency_ms = latency_ms
        self.jitter_buffer.set_target_latency(latency_ms)

    def set_device(self, device_id: int):
        self.start_stream(device_id=device_id)

    def get_devices(self) -> List[Dict[str, Any]]:
        devices = []
        try:
            device_list = sd.query_devices()
            default_out = sd.default.device[1]
            for idx, dev in enumerate(device_list):
                if dev.get('max_output_channels', 0) > 0:
                    devices.append({
                        "id": idx,
                        "name": dev['name'],
                        "hostapi": sd.query_hostapis(dev['hostapi'])['name'],
                        "channels": dev['max_output_channels'],
                        "default": idx == default_out
                    })
        except Exception as e:
            print(f"[AudioEngine] Failed to query devices: {e}")
        return devices

    def push_pcm(self, pcm_bytes: bytes):
        if not pcm_bytes:
            return
        # Ensure aligned to stereo 16-bit (4 bytes)
        usable_bytes = len(pcm_bytes) - (len(pcm_bytes) % FRAME_SIZE)
        if usable_bytes == 0:
            return
        
        arr = np.frombuffer(pcm_bytes[:usable_bytes], dtype=np.int16).reshape(-1, CHANNELS)
        self.jitter_buffer.write(arr)

    def close(self):
        self.running = False
        if self.stream is not None:
            try:
                self.stream.stop()
                self.stream.close()
            except Exception:
                pass


class AudioReceiverServer:
    def __init__(self, audio_engine: AudioEngine):
        self.engine = audio_engine
        self.udp_audio_sock: Optional[socket.socket] = None
        self.tcp_audio_sock: Optional[socket.socket] = None
        self.discovery_sock: Optional[socket.socket] = None
        self.running = False
        
        # Stats
        self.client_ip: Optional[str] = None
        self.last_packet_time: float = 0.0
        self.bytes_received: int = 0
        self.packets_received: int = 0
        self.lost_packets: int = 0
        self.last_seq: int = -1
        self.kbps: float = 0.0
        self.stats_lock = threading.Lock()

    def start(self):
        self.running = True
        
        # Audio UDP receiver
        self.udp_audio_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.udp_audio_sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024 * 1024)  # 1MB buffer
        self.udp_audio_sock.bind(("0.0.0.0", AUDIO_PORT))

        # Audio TCP receiver (for USB cable / ADB reverse streaming)
        self.tcp_audio_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.tcp_audio_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.tcp_audio_sock.bind(("0.0.0.0", AUDIO_PORT))
        self.tcp_audio_sock.listen(2)
        
        threading.Thread(target=self._audio_loop, daemon=True, name="UDP-Audio-Receiver").start()
        threading.Thread(target=self._tcp_audio_loop, daemon=True, name="TCP-Audio-Receiver").start()
        threading.Thread(target=self._discovery_loop, daemon=True, name="UDP-Discovery-Service").start()
        threading.Thread(target=self._stats_monitor, daemon=True, name="Stats-Monitor").start()
        print(f"[SoundRelay] Audio UDP & TCP Receiver listening on port {AUDIO_PORT}")
        print(f"[SoundRelay] Discovery Service listening on port {DISCOVERY_PORT}")

    def _tcp_audio_loop(self):
        """Receives audio stream over TCP (useful for USB tethering / ADB reverse)."""
        while self.running:
            try:
                conn, addr = self.tcp_audio_sock.accept()
                threading.Thread(target=self._handle_tcp_client, args=(conn, addr), daemon=True).start()
            except Exception:
                if self.running:
                    time.sleep(0.1)

    def _handle_tcp_client(self, conn: socket.socket, addr):
        conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        print(f"[SoundRelay TCP/USB] Client connected from {addr[0]}:{addr[1]}")
        with self.stats_lock:
            self.client_ip = f"USB/TCP: {addr[0]}"
        try:
            while self.running:
                data = conn.recv(4096)
                if not data:
                    break
                now = time.time()
                with self.stats_lock:
                    self.last_packet_time = now
                    self.bytes_received += len(data)
                    self.packets_received += 1
                
                # Check header
                if len(data) >= 12 and data[:4] == MAGIC:
                    pcm_data = data[12:]
                else:
                    pcm_data = data
                self.engine.push_pcm(pcm_data)
        except Exception:
            pass
        finally:
            try:
                conn.close()
            except Exception:
                pass
            print(f"[SoundRelay TCP/USB] Client {addr[0]} disconnected")
            with self.stats_lock:
                if self.client_ip and "USB/TCP" in self.client_ip:
                    self.client_ip = None

    def _audio_loop(self):
        while self.running:
            try:
                data, addr = self.udp_audio_sock.recvfrom(4096)
                if not data:
                    continue

                now = time.time()
                with self.stats_lock:
                    self.client_ip = addr[0]
                    self.last_packet_time = now
                    self.bytes_received += len(data)
                    self.packets_received += 1

                # Check if custom SRLY header (12 bytes)
                if len(data) >= 12 and data[:4] == MAGIC:
                    seq, timestamp_ms = struct.unpack("!II", data[4:12])
                    pcm_data = data[12:]
                    with self.stats_lock:
                        if self.last_seq != -1 and seq > self.last_seq + 1:
                            self.lost_packets += (seq - self.last_seq - 1)
                        self.last_seq = seq
                else:
                    # Raw PCM packet fallback
                    pcm_data = data

                self.engine.push_pcm(pcm_data)

            except Exception as e:
                if self.running:
                    time.sleep(0.005)

    def _discovery_loop(self):
        """Listens for client broadcasts and responds so phone auto-discovers PC."""
        self.discovery_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.discovery_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.discovery_sock.bind(("0.0.0.0", DISCOVERY_PORT))
        hostname = socket.gethostname()

        while self.running:
            try:
                data, addr = self.discovery_sock.recvfrom(1024)
                message = data.decode('utf-8', errors='ignore').strip()
                if message.startswith("SOUNDRELAY_DISCOVER"):
                    # Reply with hostname and audio port
                    local_ip = self._get_primary_ip()
                    reply = f"SOUNDRELAY_OFFER:{hostname}:{local_ip}:{AUDIO_PORT}:59100".encode('utf-8')
                    self.discovery_sock.sendto(reply, addr)
                    print(f"[SoundRelay] Discovered by client at {addr[0]} - Sent offer for {hostname} ({local_ip})")
            except Exception:
                if self.running:
                    time.sleep(0.1)

    def _stats_monitor(self):
        last_bytes = 0
        while self.running:
            time.sleep(1.0)
            with self.stats_lock:
                delta = self.bytes_received - last_bytes
                last_bytes = self.bytes_received
                self.kbps = (delta * 8) / 1000.0  # kilobits per second
                # Reset client status if no packet received in 3.5 seconds
                if time.time() - self.last_packet_time > 3.5:
                    self.client_ip = None

    def _get_primary_ip(self) -> str:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "127.0.0.1"

    def get_status(self) -> Dict[str, Any]:
        with self.stats_lock:
            connected = (self.client_ip is not None)
            client = self.client_ip
            kbps = round(self.kbps, 1)
            lost = self.lost_packets
            packets = self.packets_received
            
        buffered_ms = round((self.engine.jitter_buffer.available_frames / SAMPLE_RATE) * 1000.0, 1)
        return {
            "connected": connected,
            "client_ip": client,
            "bitrate_kbps": kbps,
            "lost_packets": lost,
            "packets_received": packets,
            "buffered_ms": buffered_ms,
            "target_latency_ms": self.engine.target_latency_ms,
            "volume": round(self.engine.volume, 2),
            "peak_left": round(self.engine.peak_left, 3),
            "peak_right": round(self.engine.peak_right, 3),
            "underruns": self.engine.jitter_buffer.underruns,
            "overruns": self.engine.jitter_buffer.overruns,
            "current_device": self.engine.current_device,
            "local_ip": self._get_primary_ip()
        }

    def stop(self):
        self.running = False
        if self.udp_audio_sock:
            try:
                self.udp_audio_sock.close()
            except Exception:
                pass
        if self.tcp_audio_sock:
            try:
                self.tcp_audio_sock.close()
            except Exception:
                pass
        if self.discovery_sock:
            try:
                self.discovery_sock.close()
            except Exception:
                pass
        self.engine.close()
