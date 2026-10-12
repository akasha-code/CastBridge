"""Inspect Cast or transmit synthetic/owned virtual-monitor content."""
import argparse
import ipaddress
import json
import socket
import time
import logging
from pathlib import Path

import pychromecast
from pychromecast.discovery import CastBrowser, SimpleCastListener
from zeroconf import Zeroconf

from prototype.stream import MemoryStream
from prototype.live_edge import LiveEdgeControl

class ReceiverHealth:
    """Bound disconnected or stalled playback, including stale media status."""
    def __init__(self):
        self.unavailable_since = None
        self.stalled_since = None

    def check(self, connected, content, state, now):
        if not connected or not content:
            if self.unavailable_since is None:
                self.unavailable_since = now
            elif now - self.unavailable_since > 30:
                raise RuntimeError("Receiver unavailable for 30 seconds; stopping owned capture")
        else:
            self.unavailable_since = None
        if connected and content and state in ("BUFFERING", "IDLE"):
            if self.stalled_since is None:
                self.stalled_since = now
            elif now - self.stalled_since > 15:
                raise RuntimeError("Receiver playback stalled for 15 seconds")
        else:
            self.stalled_since = None


def receiver_idle(cast, live_edge):
    status = cast.status
    if status is None or status.is_active_input:
        return False
    if status.app_id in (None, "E8C28D3C"):
        return True
    return status.app_id == "CC1AD845" and live_edge.confirm_empty()


def run(model, play=False, seconds=20, capture_target=None, device_id=None, stop_file=None, display_name=None, low_latency=False, sync_file=None, aggressive_latency=False, diagnostics=False, latency_step=1):
    logging.getLogger("pychromecast").setLevel(logging.CRITICAL)
    started = time.monotonic()
    cast = None
    stream = None
    owned_content = None
    owned_session = None
    live_edge = None
    with Zeroconf() as zconf:
        browser = CastBrowser(SimpleCastListener(), zconf)
        try:
            browser.start_discovery()
            time.sleep(10)
            candidates = [info for info in list(browser.devices.values())
                          if info.cast_type == "cast" and
                          (str(info.uuid) == device_id if device_id else info.model_name == model)]
            if len(candidates) != 1:
                raise RuntimeError(f"Expected one Cast device of model {model}; found {len(candidates)}")
            info = candidates[0]
            cast = pychromecast.get_chromecast_from_cast_info(info, zconf, tries=3,
                                                            retry_wait=1, timeout=5)
            live_edge = LiveEdgeControl(cast.media_controller)
            cast.wait(timeout=10)
            status = cast.status
            if status is None:
                raise RuntimeError("Receiver status unavailable")
            # Default Media Receiver may remain open after a failed load. Only
            # a fresh, explicit empty MEDIA_STATUS proves it has no playback.
            idle = receiver_idle(cast, live_edge)
            print(json.dumps({"model": info.model_name, "idle": idle,
                              "active_input": status.is_active_input,
                              "application_id": status.app_id}))
            if not play:
                return
            if not idle:
                raise RuntimeError("Receiver may be occupied; playback was not started")
            if stop_file and Path(stop_file).exists():
                return
            peer = str(ipaddress.IPv4Address(info.host))
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
                route.connect((peer, info.port))
                bind = route.getsockname()[0]
            stream = MemoryStream(bind=bind, peer=peer, capture_target=capture_target,
                                  low_latency=low_latency, aggressive_latency=aggressive_latency,
                                  latency_step=latency_step).start()
            playlist_ready = time.monotonic()
            # Recheck just before requesting the receiver; Cast does not offer
            # an atomic claim, so concurrent senders remain a race condition.
            cast.wait(timeout=5)
            if not receiver_idle(cast, live_edge):
                raise RuntimeError("Receiver state changed before playback")
            owned_content = stream.url
            cast.media_controller.play_media(owned_content, "application/vnd.apple.mpegurl",
                                             title=display_name or info.friendly_name, stream_type="LIVE")
            requested = time.monotonic()
            cast.media_controller.block_until_active(timeout=15)
            owned_session = cast.status.session_id if cast.status else None
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                if stop_file and Path(stop_file).exists():
                    return
                if stream.capture_failure:
                    raise RuntimeError("Capture stopped during startup: " + stream.capture_failure)
                if stream.process is None or stream.process.poll() is not None:
                    raise RuntimeError("Encoder stopped during startup: " + " | ".join(stream.encoder_errors))
                media = cast.media_controller.status
                if media.content_id == owned_content and media.player_state == "PLAYING":
                    break
                time.sleep(0.2)
            else:
                raise TimeoutError("Receiver did not confirm PLAYING for this test")
            print(json.dumps({"receiver_confirmed": "PLAYING", "visual_quality": "requires_user_observation",
                              "startup_seconds": round(time.monotonic() - started, 2),
                              "playlist_ready_seconds": round(playlist_ready - started, 2),
                              "receiver_start_seconds": round(time.monotonic() - requested, 2)}))
            deadline = time.monotonic() + seconds
            health = ReceiverHealth()
            synchronize = low_latency
            next_diagnostic = time.monotonic() + 5
            while time.monotonic() < deadline:
                if stop_file and Path(stop_file).exists():
                    break
                content = cast.media_controller.status.content_id
                if content and content != owned_content:
                    raise RuntimeError("Receiver session changed; stopping owned capture")
                connected = cast.socket_client.is_connected
                was_unavailable = health.unavailable_since is not None
                health.check(connected, content, cast.media_controller.status.player_state, time.monotonic())
                if was_unavailable != (health.unavailable_since is not None):
                    print(json.dumps({"receiver_status": "temporarily_unavailable" if health.unavailable_since is not None else "recovered"}))
                if stream.capture_failure:
                    if stream.capture_change:
                        print(json.dumps({"capture_change": stream.capture_change}))
                    raise RuntimeError("Capture stopped: " + stream.capture_failure)
                if stream.process is None or stream.process.poll() is not None:
                    code = None if stream.process is None else stream.process.returncode
                    raise RuntimeError("Encoder stopped during the Cast session: " + str(code)
                                       + " | " + " | ".join(stream.encoder_errors))
                if sync_file and Path(sync_file).exists():
                    Path(sync_file).unlink()
                    synchronize = True
                if synchronize and connected and content == owned_content:
                    synchronize = False
                    try:
                        outcome = live_edge.seek_latest(owned_content)
                    except Exception as error:
                        outcome = "request_failed:" + type(error).__name__
                    print(json.dumps({"live_sync": outcome}))
                if diagnostics and time.monotonic() >= next_diagnostic:
                    cast.media_controller.update_status()
                    print(json.dumps({"timing_diagnostic": {"encoder": stream.progress(),
                                                             "receiver": live_edge.metrics(owned_content)}}))
                    next_diagnostic = time.monotonic() + 5
                time.sleep(0.2)
        finally:
            try:
                if cast is not None and owned_content is not None and cast.socket_client.is_connected:
                    cleanup_session = owned_session
                    if cast.media_controller.status.content_id == owned_content:
                        if cast.status is not None:
                            cleanup_session = cast.status.session_id
                        cast.media_controller.stop()
                        deadline = time.monotonic() + 5
                        while time.monotonic() < deadline:
                            if cast.media_controller.status.player_state == "IDLE":
                                break
                            time.sleep(0.1)
                    if (cleanup_session is not None and cast.status is not None
                            and cast.status.session_id == cleanup_session
                            and cast.media_controller.status.content_id in (None, owned_content)):
                        cast.quit_app(timeout=5)
            finally:
                try:
                    if stream is not None:
                        stream.close()
                finally:
                    try:
                        if cast is not None:
                            if live_edge is not None:
                                live_edge.close()
                            cast.disconnect(timeout=5)
                    finally:
                        browser.stop_discovery()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default="Chromecast")
    parser.add_argument("--play-synthetic", action="store_true")
    parser.add_argument("--capture-target", help="Owned VDD target path; starts real capture")
    parser.add_argument("--seconds", type=int, default=20)
    parser.add_argument("--device-id")
    parser.add_argument("--stop-file")
    parser.add_argument("--display-name")
    parser.add_argument("--low-latency", action="store_true")
    parser.add_argument("--sync-file")
    parser.add_argument("--aggressive-latency", action="store_true")
    parser.add_argument("--diagnostics", action="store_true")
    parser.add_argument("--latency-step", type=int, choices=(1, 2), default=1)
    args = parser.parse_args()
    if args.play_synthetic and args.capture_target:
        parser.error("Choose synthetic playback or virtual capture")
    if not 1 <= args.seconds <= 86400:
        parser.error("seconds must be between 1 and 86400")
    run(args.model, args.play_synthetic or bool(args.capture_target), args.seconds, args.capture_target,
        args.device_id, args.stop_file, args.display_name, args.low_latency or args.aggressive_latency,
        args.sync_file, args.aggressive_latency, args.diagnostics, args.latency_step)
