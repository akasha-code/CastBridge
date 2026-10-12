"""Observe receiver-reported live ranges and seek only the owned media."""
import math
import threading
import time


class LiveEdgeControl:
    def __init__(self, controller):
        self.controller = controller
        self.original = controller.receive_message
        self.updated = threading.Event()
        self.lock = threading.Lock()
        self.latest = None
        controller.receive_message = self.receive_message

    def receive_message(self, message, data):
        result = self.original(message, data)
        for status in data.get("status", []):
            interval = status.get("liveSeekableRange")
            if interval is not None:
                with self.lock:
                    self.latest = (self.controller.status.content_id, dict(interval), time.monotonic())
                self.updated.set()
        return result

    def seek_latest(self, owned_content):
        if self.controller.status.content_id != owned_content:
            return "session_changed"
        self.updated.clear()
        self.controller.update_status()
        if not self.updated.wait(3):
            return "range_unavailable"
        with self.lock:
            content, interval, observed = self.latest
        if content != owned_content or self.controller.status.content_id != owned_content:
            return "session_changed"
        if not self.controller.status.supports_seek or interval.get("isLiveDone"):
            return "seek_unavailable"
        start, end = interval.get("start"), interval.get("end")
        if (not isinstance(start, (int, float)) or not isinstance(end, (int, float))
                or not math.isfinite(start) or not math.isfinite(end) or end < start
                or time.monotonic() - observed > 3):
            return "invalid_range"
        self.controller.seek(max(start, end - 0.15), timeout=5)
        return "synchronized"

    def close(self):
        self.controller.receive_message = self.original

    def confirm_empty(self):
        finished = threading.Event()
        result = []
        def response(success, data):
            result.append(bool(success and isinstance(data, dict)
                               and data.get("type") == "MEDIA_STATUS" and data.get("status") == []))
            finished.set()
        self.controller.update_status(callback_function=response)
        return bool(finished.wait(3) and result and result[0])

    def metrics(self, owned_content):
        with self.lock:
            latest = self.latest
        if latest is None or latest[0] != owned_content:
            return None
        current = self.controller.status.adjusted_current_time
        interval, age = latest[1], time.monotonic() - latest[2]
        return {"media_time_seconds": round(current, 3) if isinstance(current, (int, float)) else None,
                "live_end_seconds": interval.get("end"), "range_age_seconds": round(age, 3)}
