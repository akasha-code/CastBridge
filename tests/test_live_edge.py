import unittest
from types import SimpleNamespace
from unittest.mock import Mock

from prototype.live_edge import LiveEdgeControl


class LiveEdgeTests(unittest.TestCase):
    def controller(self, content="owned", interval=None):
        controller = Mock()
        controller.status = SimpleNamespace(content_id=content, supports_seek=True)
        controller.receive_message.return_value = True
        edge = LiveEdgeControl(controller)
        controller.update_status.side_effect = lambda: edge.receive_message(None, {
            "status": [{"liveSeekableRange": interval or {"start": 10, "end": 11}}]})
        return controller, edge

    def test_seeks_inside_fresh_live_range_and_restores_handler(self):
        controller, edge = self.controller()
        original = edge.original
        self.assertEqual(edge.seek_latest("owned"), "synchronized")
        controller.seek.assert_called_once_with(10.85, timeout=5)
        edge.close()
        self.assertEqual(controller.receive_message, original)

    def test_rejects_foreign_session(self):
        controller, edge = self.controller("foreign")
        self.assertEqual(edge.seek_latest("owned"), "session_changed")
        controller.seek.assert_not_called()

    def test_rejects_session_changed_during_status_request(self):
        controller, edge = self.controller()
        def update():
            controller.status.content_id = "foreign"
            edge.receive_message(None, {"status": [{"liveSeekableRange": {"start": 10, "end": 11}}]})
        controller.update_status.side_effect = update
        self.assertEqual(edge.seek_latest("owned"), "session_changed")
        controller.seek.assert_not_called()

    def test_rejects_invalid_live_range(self):
        controller, edge = self.controller(interval={"start": 11, "end": 10})
        self.assertEqual(edge.seek_latest("owned"), "invalid_range")
        controller.seek.assert_not_called()

    def test_empty_receiver_requires_explicit_fresh_reply(self):
        controller, edge = self.controller()
        controller.update_status.side_effect = lambda **kwargs: kwargs['callback_function'](
            True, {"type": "MEDIA_STATUS", "status": []})
        self.assertTrue(edge.confirm_empty())
        controller.update_status.side_effect = lambda **kwargs: kwargs['callback_function'](
            True, {"type": "MEDIA_STATUS", "status": [{"playerState": "PLAYING"}]})
        self.assertFalse(edge.confirm_empty())
        controller.update_status.side_effect = lambda **kwargs: kwargs['callback_function'](False, None)
        self.assertFalse(edge.confirm_empty())
