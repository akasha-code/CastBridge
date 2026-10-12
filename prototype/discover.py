"""Read-only service discovery; no receiver launch or media commands."""
import argparse
import json
import time

from pychromecast.discovery import CastBrowser, SimpleCastListener
from zeroconf import Zeroconf


def discover(seconds=10, selectable=False):
    with Zeroconf() as zconf:
        browser = CastBrowser(SimpleCastListener(), zconf)
        try:
            browser.start_discovery()
            time.sleep(seconds)
            return [dict(model=info.model_name, cast_type=info.cast_type,
                         **({"id": str(info.uuid), "name": info.friendly_name} if selectable else {}))
                    for info in list(browser.devices.values()) if not selectable or info.cast_type == "cast"]
        finally:
            browser.stop_discovery()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=int, choices=range(1, 31), default=10)
    parser.add_argument("--selectable", action="store_true", help="Local selection UI: include device names and IDs")
    args = parser.parse_args()
    devices = discover(args.seconds, args.selectable)
    print(json.dumps({"devices": devices, "count": len(devices),
                      "session_occupancy": "not_checked"}, indent=2))
