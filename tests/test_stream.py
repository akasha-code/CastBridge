import unittest
import json
import subprocess
import time
import urllib.error
import urllib.request
from unittest.mock import Mock, patch

from prototype.stream import MemoryStream


class StreamTests(unittest.TestCase):
    def test_encoder_termination_releases_stream_resources(self):
        stream = MemoryStream().start()
        url = stream.url
        encoder = stream.process
        try:
            encoder.kill()
            encoder.wait(timeout=5)
        finally:
            stream.close()
        self.assertIsNone(stream.process)
        self.assertFalse(stream.data)
        self.assertFalse(stream.threads)
        with self.assertRaises(OSError):
            urllib.request.urlopen(url, timeout=1)

    def test_synthetic_hls_and_cleanup(self):
        stream = MemoryStream()
        with stream:
            url = stream.url
            playlist = urllib.request.urlopen(url, timeout=5).read().decode()
            self.assertTrue(playlist.startswith("#EXTM3U"))
            segment = next(line for line in playlist.splitlines() if line.endswith(".ts"))
            payload = urllib.request.urlopen(url.rsplit("/", 1)[0] + "/" + segment, timeout=5).read()
            self.assertEqual(payload[0], 0x47)
            self.assertEqual(len(payload) % 188, 0)
            with self.assertRaises(urllib.error.HTTPError) as denied:
                urllib.request.urlopen(url.replace(stream.read_token, "wrong"), timeout=5)
            self.assertEqual(denied.exception.code, 403)
            with self.assertRaises(urllib.error.HTTPError) as forbidden:
                urllib.request.urlopen(urllib.request.Request(url, data=b"bad", method="PUT"), timeout=5)
            self.assertEqual(forbidden.exception.code, 403)
        self.assertIsNone(stream.process)
        self.assertFalse(stream.data)
        self.assertFalse(stream.threads)
        stream.close()
        with self.assertRaises(OSError):
            urllib.request.urlopen(url, timeout=1)

    def test_failed_encoder_closes_servers(self):
        stream = MemoryStream(ffmpeg="nonexistent-castaggregator-encoder")
        with self.assertRaises(FileNotFoundError):
            stream.start()
        self.assertIsNone(stream.read_server)
        self.assertIsNone(stream.upload_server)
        self.assertFalse(stream.threads)

    def test_short_segments_have_valid_target_duration(self):
        with MemoryStream(low_latency=True) as stream:
            playlist = urllib.request.urlopen(stream.url, timeout=5).read().decode()
            target = int(next(line.split(':')[1] for line in playlist.splitlines()
                              if line.startswith('#EXT-X-TARGETDURATION:')))
            durations = [float(line.split(':')[1].rstrip(',')) for line in playlist.splitlines()
                         if line.startswith('#EXTINF:')]
            self.assertGreaterEqual(target, 1)
            self.assertTrue(durations)
            self.assertTrue(all(0.4 <= duration <= 0.6 for duration in durations))

    def test_aggressive_profile_removes_transport_timestamp_offset(self):
        first_times = []
        for aggressive in (False, True):
            with MemoryStream(low_latency=True, aggressive_latency=aggressive) as stream:
                playlist = urllib.request.urlopen(stream.url, timeout=5).read().decode()
                segment = next(line for line in playlist.splitlines() if line.endswith('.ts'))
                payload = urllib.request.urlopen(stream.url.rsplit('/', 1)[0] + '/' + segment, timeout=5).read()
                probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
                                        '-show_entries', 'packet=pts_time', '-of', 'json', '-i', 'pipe:0'],
                                       input=payload, capture_output=True, check=True, timeout=10)
                first_times.append(float(json.loads(probe.stdout)['packets'][0]['pts_time']))
                deadline = time.monotonic() + 3
                while stream.progress() is None and time.monotonic() < deadline:
                    time.sleep(0.05)
                self.assertIsNotNone(stream.progress())
        self.assertGreater(first_times[0] - first_times[1], 1)
        self.assertGreaterEqual(first_times[1], 0)

    def test_rejects_wildcard_bind(self):
        with self.assertRaises(ValueError):
            MemoryStream(bind="0.0.0.0")

    def test_rejects_physical_capture_before_starting_resources(self):
        stream = MemoryStream(capture_target="physical-display")
        with self.assertRaises(ValueError):
            stream.start()
        self.assertIsNone(stream.process)
        self.assertIsNone(stream.read_server)

    def test_topology_change_stops_capture(self):
        stream = MemoryStream(capture_target="owned#MTT1337#target")
        stream.capture_signature = ["before"]
        stream.process = Mock()
        stream.process.poll.return_value = None
        with patch.object(stream.stop_watch, "wait", return_value=False), patch.object(stream, "_capture_state", return_value=({}, ["after"])):
            stream._watch_capture()
        stream.process.terminate.assert_called_once()
        self.assertEqual(stream.capture_failure, "Display topology changed during capture")

    def test_source_renumbering_preserves_capture_identity(self):
        target = "owned#MTT1337#target"
        row = dict(target_path=target, source="display1", x=3000, y=0,
                   width=1280, height=720, rotation=1)
        bounds = dict(x=3000, y=0, width=1280, height=720, primary=False)
        stream = MemoryStream(capture_target=target)
        with patch("prototype.windows_display.topology", return_value=[row]), patch(
                "prototype.windows_display.monitor_bounds", return_value={"display1": bounds}):
            _, before = stream._capture_state()
        row = dict(row, source="display2")
        with patch("prototype.windows_display.topology", return_value=[row]), patch(
                "prototype.windows_display.monitor_bounds", return_value={"display2": bounds}):
            _, after = stream._capture_state()
        self.assertEqual(before, after)
        row = dict(row, x=3100)
        with patch("prototype.windows_display.topology", return_value=[row]), patch(
                "prototype.windows_display.monitor_bounds", return_value={"display2": dict(bounds, x=3100)}):
            _, moved = stream._capture_state()
        self.assertNotEqual(before, moved)


if __name__ == "__main__":
    unittest.main()
