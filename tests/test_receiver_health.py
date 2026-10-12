import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch
from prototype import cast as transport
from prototype.cast import ReceiverHealth


class ReceiverHealthTests(unittest.TestCase):
    def test_disconnected_socket_with_stale_playing_status_expires(self):
        health = ReceiverHealth()
        health.check(False, "owned", "PLAYING", 0)
        with self.assertRaisesRegex(RuntimeError, "unavailable"):
            health.check(False, "owned", "PLAYING", 31)

    def test_short_interruption_recovers_and_resets_deadline(self):
        health = ReceiverHealth()
        health.check(False, "owned", "PLAYING", 0)
        health.check(True, "owned", "PLAYING", 29)
        health.check(False, "owned", "PLAYING", 40)
        health.check(False, "owned", "PLAYING", 69)

    def test_buffering_expires(self):
        health = ReceiverHealth()
        health.check(True, "owned", "BUFFERING", 0)
        with self.assertRaisesRegex(RuntimeError, "stalled"):
            health.check(True, "owned", "BUFFERING", 16)

    def test_missing_content_expires(self):
        health = ReceiverHealth()
        health.check(True, None, "UNKNOWN", 0)
        with self.assertRaisesRegex(RuntimeError, "unavailable"):
            health.check(True, None, "UNKNOWN", 31)

    def test_disconnection_runs_transport_cleanup(self):
        controller = Mock()
        controller.status = SimpleNamespace(content_id=None, player_state="UNKNOWN")
        receiver = Mock()
        receiver.status = SimpleNamespace(is_active_input=False, app_id=None, session_id="owned")
        receiver.media_controller = controller
        receiver.socket_client.is_connected = False
        stream = Mock()
        stream.start.return_value = stream
        stream.url = "http://owned-stream"
        stream.capture_failure = None
        stream.process.poll.return_value = None
        controller.play_media.side_effect = lambda *a, **k: setattr(controller, "status", SimpleNamespace(content_id=stream.url, player_state="PLAYING"))
        browser = Mock()
        browser.devices = {"test": SimpleNamespace(cast_type="cast", uuid="test", model_name="Chromecast", host="127.0.0.1", port=8009, friendly_name="Synthetic receiver")}
        clock = iter(n / 2 for n in range(1000))
        with patch.object(transport, "Zeroconf"), patch.object(transport, "CastBrowser", return_value=browser), patch.object(transport.pychromecast, "get_chromecast_from_cast_info", return_value=receiver), patch.object(transport, "MemoryStream", return_value=stream), patch.object(transport, "LiveEdgeControl"), patch.object(transport.time, "sleep"), patch.object(transport.time, "monotonic", side_effect=lambda: next(clock)):
            with self.assertRaisesRegex(RuntimeError, "unavailable"):
                transport.run("Chromecast", play=True, seconds=100)
        stream.close.assert_called_once()
        receiver.disconnect.assert_called_once()
        browser.stop_discovery.assert_called_once()
        controller.stop.assert_not_called()
