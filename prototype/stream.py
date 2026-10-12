"""Synthetic or identified virtual-monitor HLS, in bounded process memory.

Upload is loopback-only. Read access is limited to a caller-selected peer and
loopback. A separate read token is never printed or written to disk.
"""
import collections
import http.server
import ipaddress
import re
import secrets
import subprocess
import threading
import time
import math
from pathlib import Path


class MemoryStream:
    def __init__(self, bind="127.0.0.1", peer="127.0.0.1", ffmpeg="ffmpeg", capture_target=None, low_latency=False, aggressive_latency=False, latency_step=1):
        if latency_step not in (1, 2):
            raise ValueError("Invalid latency step")
        ip = ipaddress.IPv4Address(bind)
        target = ipaddress.IPv4Address(peer)
        if ip.is_unspecified or ip.is_multicast or not (ip.is_private or ip.is_loopback):
            raise ValueError("Bind must be a specific local IPv4 address")
        if target.is_unspecified or target.is_multicast or not target.is_private:
            raise ValueError("Peer must be a private IPv4 address")
        bundled_ffmpeg = Path(__file__).resolve().parent.parent / "bin" / "ffmpeg.exe"
        self.bind, self.peer = str(ip), str(target)
        self.ffmpeg = str(bundled_ffmpeg) if ffmpeg == "ffmpeg" and bundled_ffmpeg.is_file() else ffmpeg
        self.read_token = secrets.token_urlsafe(32)
        self.write_token = secrets.token_urlsafe(32)
        self.data = collections.OrderedDict()
        self.lock = threading.Lock()
        self.upload_server = self.read_server = self.process = None
        self.threads = []
        self.encoder_errors = collections.deque(maxlen=10)
        self.capture_target = capture_target
        self.low_latency = low_latency
        self.aggressive_latency = aggressive_latency
        self.latency_step = latency_step
        self.encoder_started = None
        self.encoder_progress = None
        self.capture_failure = None
        self.capture_change = None
        self.capture_signature = None
        self.stop_watch = threading.Event()

    def _capture_state(self):
        from prototype.windows_display import monitor_bounds, topology
        if not self.capture_target or "#MTT1337#" not in self.capture_target:
            raise ValueError("Capture requires an identified VDD target")
        rows = topology()
        selected = [row for row in rows if row["target_path"] == self.capture_target]
        if len(selected) != 1:
            raise RuntimeError("Owned virtual target is unavailable")
        row = selected[0]
        if any(other["source"] == row["source"] for other in rows if other is not row):
            raise RuntimeError("Refusing capture of a cloned source")
        screens = monitor_bounds()
        bounds = screens.get(row["source"])
        if bounds is None or bounds["primary"] or (bounds["width"], bounds["height"]) != (1280, 720):
            raise RuntimeError("Virtual capture bounds are invalid")
        for source, other in screens.items():
            if source == row["source"]:
                continue
            if (bounds["x"] < other["x"] + other["width"] and other["x"] < bounds["x"] + bounds["width"]
                    and bounds["y"] < other["y"] + other["height"] and other["y"] < bounds["y"] + bounds["height"]):
                raise RuntimeError("Virtual capture region overlaps another screen")
        # GDI source numbers can change without moving or replacing a target.
        # Ownership, clone exclusion and physical bounds are checked above.
        signature = sorted((entry["target_path"], entry["x"], entry["y"],
                            entry["width"], entry["height"], entry["rotation"]) for entry in rows)
        return bounds, signature

    def _watch_capture(self):
        while not self.stop_watch.wait(0.25):
            try:
                _, signature = self._capture_state()
                if signature != self.capture_signature:
                    self.capture_change = {
                        "before_geometry": [entry[1:] for entry in self.capture_signature],
                        "after_geometry": [entry[1:] for entry in signature],
                    }
                    raise RuntimeError("Display topology changed during capture")
            except Exception as error:
                self.capture_failure = str(error)
                if self.process is not None and self.process.poll() is None:
                    self.process.terminate()
                return

    def _read_encoder_errors(self, pipe):
        for line in iter(pipe.readline, b""):
            message = line.decode("utf-8", errors="replace").strip()
            self.encoder_errors.append(re.sub(r"https?://\S+", "[stream-url]", message))
        pipe.close()

    def _read_encoder_progress(self, pipe):
        record = {}
        for line in iter(pipe.readline, b""):
            key, separator, value = line.decode("ascii", errors="replace").strip().partition("=")
            if not separator:
                continue
            if key in ("frame", "out_time_us"):
                try:
                    record[key] = int(value)
                except ValueError:
                    continue
            elif key == "progress":
                if record.get("out_time_us", -1) >= 0:
                    elapsed = time.monotonic() - self.encoder_started
                    duration = record["out_time_us"] / 1_000_000
                    with self.lock:
                        self.encoder_progress = {"elapsed_seconds": round(elapsed, 3),
                                                 "output_time_seconds": round(duration, 3),
                                                 "progress_gap_seconds": round(elapsed - duration, 3),
                                                 "frames": record.get("frame")}
                record = {}
        pipe.close()

    def progress(self):
        with self.lock:
            return dict(self.encoder_progress) if self.encoder_progress else None

    def _handler(self, upload):
        owner = self

        class Handler(http.server.BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.0"

            def log_message(self, *args):
                pass  # URLs contain access tokens.

            def setup(self):
                super().setup()
                self.connection.settimeout(5)

            def _key(self):
                token = owner.write_token if upload else owner.read_token
                match = re.fullmatch(r"/" + re.escape(token) + r"/(index\.m3u8|segment\d+\.ts)", self.path)
                return match.group(1) if match else None

            def do_PUT(self):
                key = self._key()
                if not upload or self.client_address[0] != "127.0.0.1" or not key:
                    self.send_error(403)
                    return
                try:
                    if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
                        payload = bytearray()
                        while True:
                            line = self.rfile.readline(128)
                            size = int(line.strip().split(b";", 1)[0], 16)
                            if size < 0 or len(payload) + size > 4 * 1024 * 1024:
                                raise ValueError("Upload exceeds memory limit")
                            if size == 0:
                                if self.rfile.readline(128) != b"\r\n":
                                    raise ValueError("Trailers are unsupported")
                                break
                            chunk = self.rfile.read(size)
                            if len(chunk) != size or self.rfile.read(2) != b"\r\n":
                                raise ValueError("Truncated upload")
                            payload.extend(chunk)
                        payload = bytes(payload)
                    else:
                        length = int(self.headers.get("Content-Length", "0"))
                        if not 0 < length <= 4 * 1024 * 1024:
                            raise ValueError("Invalid upload length")
                        payload = self.rfile.read(length)
                        if len(payload) != length:
                            raise ValueError("Truncated upload")
                except ValueError:
                    self.send_error(400)
                    return
                if key == "index.m3u8":
                    # FFmpeg may emit absolute upload URLs. Publish relative URLs.
                    lines = payload.decode("utf-8").splitlines()
                    durations = [float(line.split(":", 1)[1].rstrip(",")) for line in lines
                                 if line.startswith("#EXTINF:")]
                    minimum_target = max(1, math.floor(max(durations, default=1) + 0.5))
                    normalized = []
                    for line in lines:
                        if line.startswith("#EXT-X-TARGETDURATION:"):
                            line = "#EXT-X-TARGETDURATION:" + str(max(minimum_target, int(line.split(":", 1)[1])))
                        if line and not line.startswith("#"):
                            line = line.rsplit("/", 1)[-1]
                            if not re.fullmatch(r"segment\d+\.ts", line):
                                self.send_error(400)
                                return
                        normalized.append(line)
                    payload = ("\n".join(normalized) + "\n").encode()
                with owner.lock:
                    owner.data[key] = payload
                    owner.data.move_to_end(key)
                    segments = [name for name in owner.data if name.endswith(".ts")]
                    for name in segments[:-8]:
                        del owner.data[name]
                self.send_response(200)
                self.send_header("Content-Length", "0")
                self.end_headers()

            def do_GET(self):
                self._read(False)

            def do_HEAD(self):
                self._read(True)

            def _read(self, head):
                key = self._key()
                if upload or self.client_address[0] not in {owner.peer, "127.0.0.1", owner.bind} or not key:
                    self.send_error(403)
                    return
                with owner.lock:
                    payload = owner.data.get(key)
                if payload is None:
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header("Content-Type", "application/vnd.apple.mpegurl" if key.endswith("m3u8") else "video/mp2t")
                self.send_header("Content-Length", str(len(payload)))
                self.send_header("Cache-Control", "no-store")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                if not head:
                    self.wfile.write(payload)

        return Handler

    def start(self, timeout=12):
        if self.read_server is not None:
            raise RuntimeError("Stream already started")
        try:
            self.stop_watch.clear()
            self.capture_failure = None
            self.capture_change = None
            input_args = ["-re", "-f", "lavfi", "-i", "testsrc2=size=1280x720:rate=15"]
            if self.capture_target:
                bounds, self.capture_signature = self._capture_state()
                input_args = ["-f", "gdigrab", "-draw_mouse", "1", "-framerate", "15",
                              "-offset_x", str(bounds["x"]), "-offset_y", str(bounds["y"]),
                              "-video_size", "1280x720", "-i", "desktop"]
            for attribute, bind, upload in (("upload_server", "127.0.0.1", True),
                                             ("read_server", self.bind, False)):
                server = http.server.ThreadingHTTPServer((bind, 0), self._handler(upload))
                server.daemon_threads = True
                setattr(self, attribute, server)
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                thread.start()
                self.threads.append(thread)
            port = self.upload_server.server_address[1]
            base = f"http://127.0.0.1:{port}/{self.write_token}/"
            gop = "8" if self.low_latency else "15"
            segment_time = "0.5" if self.low_latency else "1"
            playlist_size = "4"
            if self.aggressive_latency:
                if self.latency_step >= 2:
                    playlist_size = "3"
            command = [self.ffmpeg, "-hide_banner", "-loglevel", "error",
                       "-nostats", "-stats_period", "0.5", "-progress", "pipe:1"] + input_args + [
                       "-an", "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p",
                       "-tune", "zerolatency", "-crf", "18", "-maxrate", "4M", "-bufsize", "1M" if self.low_latency else "2M",
                       "-g", gop, "-keyint_min", gop, "-sc_threshold", "0",
                       "-f", "hls", "-hls_time", segment_time, "-hls_list_size", playlist_size,
                       "-hls_segment_options", "mpegts_copyts=1" if self.aggressive_latency else "mpegts_copyts=0",
                       *(["-muxdelay", "0", "-muxpreload", "0"] if self.aggressive_latency else []),
                       "-hls_segment_filename", base + "segment%d.ts", "-method", "PUT",
                       base + "index.m3u8"]
            self.encoder_started = time.monotonic()
            self.encoder_progress = None
            self.process = subprocess.Popen(command, stdin=subprocess.DEVNULL,
                                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            thread = threading.Thread(target=self._read_encoder_progress,
                                      args=(self.process.stdout,), daemon=True)
            thread.start()
            self.threads.append(thread)
            thread = threading.Thread(target=self._read_encoder_errors,
                                      args=(self.process.stderr,), daemon=True)
            thread.start()
            self.threads.append(thread)
            if self.capture_target:
                watcher = threading.Thread(target=self._watch_capture, daemon=True)
                watcher.start()
                self.threads.append(watcher)
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                if self.process.poll() is not None:
                    raise RuntimeError(f"Synthetic encoder exited with code {self.process.returncode}: "
                                       + " | ".join(self.encoder_errors))
                with self.lock:
                    ready = "index.m3u8" in self.data
                if ready:
                    return self
                time.sleep(0.1)
            raise TimeoutError("Synthetic HLS encoder did not publish a playlist: "
                               + " | ".join(self.encoder_errors))
        except BaseException:
            self.close()
            raise

    @property
    def url(self):
        if self.read_server is None:
            raise RuntimeError("Stream is not running")
        return f"http://{self.bind}:{self.read_server.server_address[1]}/{self.read_token}/index.m3u8"

    def close(self):
        self.stop_watch.set()
        if self.process is not None:
            if self.process.poll() is None:
                self.process.terminate()
                try:
                    self.process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    self.process.kill()
                    self.process.wait(timeout=5)
            self.process = None
        for server in (self.read_server, self.upload_server):
            if server:
                server.shutdown()
                server.server_close()
        for thread in self.threads:
            thread.join(timeout=5)
        self.threads.clear()
        self.read_server = self.upload_server = None
        with self.lock:
            self.data.clear()

    def __enter__(self):
        return self.start()

    def __exit__(self, *args):
        self.close()
