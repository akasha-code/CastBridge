"""Bounded IPv4 mDNS probe. Does not launch receivers or expose device names."""
import json
import socket
import struct
import time


def probe(seconds=5):
    service = b"".join(bytes([len(p)]) + p for p in
                       [b"_googlecast", b"_tcp", b"local"]) + b"\0"
    # QU requests a unicast reply to the ephemeral source port.
    query = struct.pack("!6H", 0, 0, 1, 0, 0, 0) + service + struct.pack("!2H", 12, 0x8001)
    responders = set()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 1)
        sock.bind(("0.0.0.0", 0))
        sock.sendto(query, ("224.0.0.251", 5353))
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            sock.settimeout(max(0.01, deadline - time.monotonic()))
            try:
                data, peer = sock.recvfrom(65535)
            except socket.timeout:
                break
            if len(data) >= 12 and data[2] & 0x80 and b"_googlecast" in data.lower():
                responders.add(peer[0])
    return {"googlecast_responding_hosts": len(responders),
            "duration_seconds": seconds,
            "limitation": "IPv4 default interface, unicast replies only; zero does not prove absence. Model, firmware and session occupancy unverified."}


if __name__ == "__main__":
    try:
        print(json.dumps(probe(), indent=2))
    except OSError as error:
        print(json.dumps({"error": str(error)}))
        raise SystemExit(1)
