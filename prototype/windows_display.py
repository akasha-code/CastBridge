"""Read-only Windows display topology with stable adapter/target identifiers."""
import ctypes as C
import json
import sys
from ctypes import wintypes as W


class Luid(C.Structure):
    _fields_ = [("low", W.DWORD), ("high", W.LONG)]


class Source(C.Structure):
    _fields_ = [("adapter", Luid), ("id", W.UINT), ("mode", W.UINT), ("flags", W.UINT)]


class Rational(C.Structure):
    _fields_ = [("numerator", W.UINT), ("denominator", W.UINT)]


class Target(C.Structure):
    _fields_ = [("adapter", Luid), ("id", W.UINT), ("mode", W.UINT),
                ("technology", W.UINT), ("rotation", W.UINT), ("scaling", W.UINT),
                ("refresh", Rational), ("scanline", W.UINT), ("available", W.BOOL), ("flags", W.UINT)]


class Path(C.Structure):
    _fields_ = [("source", Source), ("target", Target), ("flags", W.UINT)]


class Mode(C.Structure):
    _fields_ = [("kind", W.UINT), ("id", W.UINT), ("adapter", Luid), ("data", C.c_uint64 * 6)]


class Header(C.Structure):
    _fields_ = [("type", W.UINT), ("size", W.UINT), ("adapter", Luid), ("id", W.UINT)]


class SourceName(C.Structure):
    _fields_ = [("header", Header), ("name", W.WCHAR * 32)]


class TargetName(C.Structure):
    _fields_ = [("header", Header), ("flags", W.UINT), ("technology", W.UINT),
                ("manufacturer", W.WORD), ("product", W.WORD), ("connector", W.UINT),
                ("friendly", W.WCHAR * 64), ("path", W.WCHAR * 128)]


def topology():
    if sys.platform != "win32":
        raise RuntimeError("Windows display API required")
    user = C.WinDLL("user32", use_last_error=True)
    if (C.sizeof(Path), C.sizeof(Mode), C.sizeof(TargetName)) != (72, 64, 420):
        raise RuntimeError("Unexpected Windows ABI layout")
    for _ in range(3):
        paths_count, modes_count = W.UINT(), W.UINT()
        result = user.GetDisplayConfigBufferSizes(2, C.byref(paths_count), C.byref(modes_count))
        if result:
            raise C.WinError(result)
        paths, modes = (Path * paths_count.value)(), (Mode * modes_count.value)()
        result = user.QueryDisplayConfig(2, C.byref(paths_count), paths, C.byref(modes_count), modes, None)
        if result == 122:
            continue
        if result:
            raise C.WinError(result)
        break
    else:
        raise RuntimeError("Display topology keeps changing")
    screens = []
    for entry in paths[:paths_count.value]:
        source_name, target_name = SourceName(), TargetName()
        for packet, kind, part in ((source_name, 1, entry.source), (target_name, 2, entry.target)):
            packet.header = Header(kind, C.sizeof(packet), part.adapter, part.id)
            result = user.DisplayConfigGetDeviceInfo(C.byref(packet))
            if result:
                raise C.WinError(result)
        if entry.source.mode >= modes_count.value:
            raise RuntimeError("Missing source mode")
        mode = modes[entry.source.mode]
        if mode.kind != 1:
            raise RuntimeError("Unexpected source mode kind")
        raw = bytes(mode.data)
        import struct
        width, height, pixel_format, x, y = struct.unpack_from("<IIIii", raw)
        key = f"{entry.target.adapter.high}:{entry.target.adapter.low}:{entry.target.id}"
        screens.append({"key": key, "source": source_name.name, "target_path": target_name.path,
                        "friendly": target_name.friendly, "x": x, "y": y,
                        "width": width, "height": height, "rotation": entry.target.rotation,
                        "refresh_numerator": entry.target.refresh.numerator,
                        "refresh_denominator": entry.target.refresh.denominator})
    return screens


def physical_unchanged(before, after):
    current = {screen["target_path"]: screen for screen in after}
    fields = ("x", "y", "width", "height", "rotation",
              "refresh_numerator", "refresh_denominator")
    return all(screen["target_path"] in current and all(screen[field] == current[screen["target_path"]][field]
                                               for field in fields) for screen in before)


def raw_query(flags=2):
    user = C.WinDLL("user32", use_last_error=True)
    for _ in range(3):
        np, nm = W.UINT(), W.UINT()
        result = user.GetDisplayConfigBufferSizes(flags, C.byref(np), C.byref(nm))
        if result:
            raise C.WinError(result)
        paths, modes = (Path * np.value)(), (Mode * nm.value)()
        result = user.QueryDisplayConfig(flags, C.byref(np), paths, C.byref(nm), modes, None)
        if result == 122:
            continue
        if result:
            raise C.WinError(result)
        return list(paths[:np.value]), list(modes[:nm.value])
    raise RuntimeError("Topology keeps changing")


def target_name(path):
    packet = TargetName()
    packet.header = Header(2, C.sizeof(packet), path.target.adapter, path.target.id)
    result = C.WinDLL("user32").DisplayConfigGetDeviceInfo(C.byref(packet))
    if result:
        raise C.WinError(result)
    return packet.path


def monitor_bounds():
    user = C.WinDLL("user32", use_last_error=True)
    user.SetProcessDpiAwarenessContext(C.c_void_p(-4))

    class Info(C.Structure):
        _fields_ = [("size", W.DWORD), ("bounds", W.RECT), ("work", W.RECT),
                    ("flags", W.DWORD), ("name", W.WCHAR * 32)]

    result, errors = {}, []
    callback_type = C.WINFUNCTYPE(W.BOOL, W.HANDLE, W.HDC, C.POINTER(W.RECT), W.LPARAM)

    def callback(handle, dc, rectangle, data):
        packet = Info()
        packet.size = C.sizeof(packet)
        if not user.GetMonitorInfoW(handle, C.byref(packet)):
            errors.append(C.get_last_error())
            return False
        rect = packet.bounds
        result[packet.name] = {"x": rect.left, "y": rect.top,
                              "width": rect.right - rect.left,
                              "height": rect.bottom - rect.top,
                              "primary": bool(packet.flags & 1)}
        return True

    user.GetMonitorInfoW.argtypes = [W.HANDLE, C.c_void_p]
    if not user.EnumDisplayMonitors(None, None, callback_type(callback), 0) or errors:
        raise C.WinError(errors[0] if errors else C.get_last_error())
    return result


if __name__ == "__main__":
    print(json.dumps(topology(), indent=2))
