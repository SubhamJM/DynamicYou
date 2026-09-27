#!/usr/bin/env python3
"""
Voice Dictation Worker for Quickshell Dynamic Island Notch
Uses faster-whisper (tiny.en) for high-speed local offline transcription.
Provides real-time FFT waveform audio energy and direct typing via wtype + wl-copy.
"""

import sys
import os
import time
import json
import math
import struct
import shutil
import threading
import subprocess

# Resting wave bars when silent
REST_BARS = [0.25, 0.45, 0.7, 0.9, 0.7, 0.45, 0.25]

def emit(event_dict):
    """Write a JSON event line to stdout for Quickshell."""
    try:
        sys.stdout.write(json.dumps(event_dict) + "\n")
        sys.stdout.flush()
    except Exception:
        pass

def compute_fft_bars(samples, num_bars=7):
    """Compute normalized frequency band energy bars for audio visualization."""
    try:
        import numpy as np
        if len(samples) < 128:
            return REST_BARS
        
        arr = np.array(samples, dtype=np.float32)
        norm = np.max(np.abs(arr))
        if norm < 0.005:
            # Essentially silence
            return [round(b * 0.4, 2) for b in REST_BARS]

        windowed = arr * np.hanning(len(arr))
        fft = np.abs(np.fft.rfft(windowed))
        if len(fft) < num_bars:
            return REST_BARS

        band_edges = np.logspace(np.log10(1), np.log10(len(fft)), num_bars + 1).astype(int)
        bars = []
        for i in range(num_bars):
            s = band_edges[i]
            e = max(s + 1, band_edges[i+1])
            val = float(np.mean(fft[s:e]))
            # Dynamic scaling
            scaled = min(1.0, val / 14.0)
            bars.append(round(max(0.12, scaled), 3))
        return bars
    except Exception:
        return REST_BARS

class DictationWorker:
    def __init__(self):
        self.model = None
        self.is_recording = False
        self.stop_requested = threading.Event()
        self.record_thread = None
        self.audio_frames = bytearray()
        self.lock = threading.Lock()

    def load_model(self):
        try:
            import faster_whisper
            # Load tiny.en on CPU with int8 quantization for minimal memory & <500ms latency
            self.model = faster_whisper.WhisperModel(
                "tiny.en",
                device="cpu",
                compute_type="int8",
                cpu_threads=4
            )
            emit({"event": "ready", "model": "tiny.en"})
        except Exception as e:
            emit({"event": "error", "message": f"Failed to load Whisper: {str(e)}"})

    def start_recording(self):
        with self.lock:
            if self.is_recording:
                return
            self.is_recording = True
            self.stop_requested.clear()
            self.audio_frames = bytearray()

        self.record_thread = threading.Thread(target=self._record_loop, daemon=True)
        self.record_thread.start()
        emit({"event": "state", "state": "listening"})

    def _record_loop(self):
        """Continuously reads audio from pw-record and streams FFT levels."""
        # Find best available recording command (prefer pw-record, fallback to arecord)
        cmd = None
        if shutil.which("pw-record"):
            cmd = ["pw-record", "--rate", "16000", "--channels", "1", "--format", "s16", "-"]
        elif shutil.which("arecord"):
            cmd = ["arecord", "-r", "16000", "-c", "1", "-f", "S16_LE", "-t", "raw", "-"]
        else:
            emit({"event": "error", "message": "Neither pw-record nor arecord found"})
            with self.lock:
                self.is_recording = False
            return

        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL
            )
        except Exception as e:
            emit({"event": "error", "message": f"Failed to spawn audio recorder: {e}"})
            with self.lock:
                self.is_recording = False
            return

        chunk_size = 1280  # 640 samples @ 16kHz s16 = 40ms
        sample_history = []

        try:
            while not self.stop_requested.is_set():
                raw = proc.stdout.read(chunk_size)
                if not raw:
                    break
                
                with self.lock:
                    self.audio_frames.extend(raw)

                # Parse samples for FFT & RMS
                count = len(raw) // 2
                if count > 0:
                    samples = struct.unpack(f"<{count}h", raw)
                    # Convert to normalized float
                    float_samples = [s / 32768.0 for s in samples]
                    sum_sq = sum(s * s for s in float_samples)
                    rms = math.sqrt(sum_sq / count)

                    sample_history.extend(float_samples)
                    if len(sample_history) >= 640:
                        bars = compute_fft_bars(sample_history[-640:], num_bars=7)
                        emit({
                            "event": "level",
                            "level": round(min(1.0, rms * 4.0), 3),
                            "bars": bars
                        })
                        sample_history = sample_history[-320:]
        except Exception as e:
            pass
        finally:
            try:
                proc.terminate()
                proc.wait(timeout=0.5)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass

    def stop_recording(self):
        with self.lock:
            if not self.is_recording:
                return
            self.is_recording = False
            self.stop_requested.set()

        if self.record_thread:
            self.record_thread.join(timeout=1.0)
            self.record_thread = None

        emit({"event": "state", "state": "transcribing"})

        # Run transcription in a background thread so worker stdin remains responsive
        threading.Thread(target=self._transcribe_and_type, args=(bytes(self.audio_frames),), daemon=True).start()

    def cancel_recording(self):
        with self.lock:
            self.is_recording = False
            self.stop_requested.set()
            self.audio_frames = bytearray()

        if self.record_thread:
            self.record_thread.join(timeout=1.0)
            self.record_thread = None

        emit({"event": "cancelled"})

    def _transcribe_and_type(self, raw_bytes):
        if len(raw_bytes) < 3200:  # < 0.1 second of audio
            emit({"event": "empty"})
            return

        if not self.model:
            emit({"event": "error", "message": "Model not loaded"})
            return

        try:
            import numpy as np
            audio_int16 = np.frombuffer(raw_bytes, dtype=np.int16)
            audio_float32 = audio_int16.astype(np.float32) / 32768.0

            # Check if total audio was just pure background silence
            rms_total = np.sqrt(np.mean(audio_float32 ** 2))
            if rms_total < 0.003:
                emit({"event": "empty"})
                return

            segments, info = self.model.transcribe(
                audio_float32,
                beam_size=1,
                language="en",
                temperature=0.0,
                vad_filter=True
            )

            text_pieces = [s.text.strip() for s in segments if s.text.strip()]
            final_text = " ".join(text_pieces).strip()

            if not final_text:
                emit({"event": "empty"})
                return

            # 1. Copy to system clipboard (wl-copy)
            try:
                subprocess.run(["wl-copy", "--", final_text], check=False, timeout=2)
            except Exception:
                pass

            # 2. Type directly into focused window (wtype)
            # Give a tiny 60ms delay so focus is completely settled
            time.sleep(0.06)
            try:
                subprocess.run(["wtype", "--", final_text], check=False, timeout=3)
            except Exception as e:
                # wtype fallback
                pass

            emit({"event": "done", "text": final_text})
        except Exception as e:
            emit({"event": "error", "message": str(e)})

    def run_worker_loop(self):
        self.load_model()
        for line in sys.stdin:
            cmd = line.strip().upper()
            if cmd == "START":
                self.start_recording()
            elif cmd == "STOP":
                self.stop_recording()
            elif cmd == "CANCEL":
                self.cancel_recording()
            elif cmd == "PING":
                emit({"event": "pong"})
            elif cmd == "QUIT":
                break

def cli_ipc(action):
    """Invoke Quickshell notch IPC for CLI triggers."""
    target_methods = {
        "start": "startDictation",
        "stop": "stopDictation",
        "toggle": "toggleDictation",
        "cancel": "cancelDictation"
    }
    method = target_methods.get(action, "toggleDictation")
    try:
        res = subprocess.run(["qs", "ipc", "call", "notch", method], capture_output=True, text=True, timeout=2)
        print(res.stdout.strip() if res.stdout else res.stderr.strip())
    except Exception as e:
        print(f"Error calling quickshell IPC: {e}")

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "worker"
    if mode == "worker":
        worker = DictationWorker()
        worker.run_worker_loop()
    elif mode in ("start", "stop", "toggle", "cancel"):
        cli_ipc(mode)
    else:
        print("Usage: voice_dictation.py [worker|start|stop|toggle|cancel]")
