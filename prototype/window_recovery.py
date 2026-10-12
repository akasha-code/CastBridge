"""Move visible windows from the owned virtual monitor to the primary screen."""
import argparse
import ctypes as C
import json
from ctypes import wintypes as W

from prototype.windows_display import monitor_bounds, topology


def recover(target):
    rows = topology()
    owned = [row for row in rows if row["target_path"] == target and "#MTT1337#" in target]
    if len(owned) != 1 or any(row["source"] == owned[0]["source"] for row in rows if row is not owned[0]):
        raise RuntimeError("Cannot identify an independent owned monitor for window recovery")
    screens = monitor_bounds()
    virtual = screens[owned[0]["source"]]
    primary = next(bounds for bounds in screens.values() if bounds["primary"])
    if virtual["primary"]:
        raise RuntimeError("Refusing recovery from the primary monitor")
    user = C.WinDLL("user32", use_last_error=True)
    user.GetWindowRect.argtypes = [W.HWND, C.POINTER(W.RECT)]
    user.IsWindowVisible.argtypes = [W.HWND]
    user.IsZoomed.argtypes = [W.HWND]
    user.GetClassNameW.argtypes = [W.HWND, W.LPWSTR, C.c_int]
    user.GetWindowLongPtrW.argtypes = [W.HWND, C.c_int]
    user.GetWindowLongPtrW.restype = C.c_ssize_t
    user.ShowWindow.argtypes = [W.HWND, C.c_int]
    user.SetWindowPos.argtypes = [W.HWND, W.HWND, C.c_int, C.c_int, C.c_int, C.c_int, W.UINT]
    moved, errors = [], []

    def callback(handle, param):
        if not user.IsWindowVisible(handle):
            return True
        name = C.create_unicode_buffer(256)
        if not user.GetClassNameW(handle, name, len(name)):
            errors.append(C.get_last_error())
            return True
        if name.value in {"Shell_TrayWnd", "Shell_SecondaryTrayWnd", "Progman", "WorkerW", "tooltips_class32"}:
            return True
        if user.GetWindowLongPtrW(handle, -20) & 0x80:
            return True
        rect = W.RECT()
        if not user.GetWindowRect(handle, C.byref(rect)):
            errors.append(C.get_last_error())
            return True
        if not (virtual["x"] <= rect.left < virtual["x"] + virtual["width"]
                and virtual["y"] <= rect.top < virtual["y"] + virtual["height"]):
            return True
        zoomed = bool(user.IsZoomed(handle))
        if zoomed:
            user.ShowWindow(handle, 9)
        if not user.SetWindowPos(handle, None, primary["x"] + 30, primary["y"] + 50, 0, 0, 0x15):
            errors.append(C.get_last_error())
        else:
            moved.append(handle)
        if zoomed:
            user.ShowWindow(handle, 3)
        return True

    callback_type = C.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
    if not user.EnumWindows(callback_type(callback), 0):
        raise C.WinError(C.get_last_error())
    if errors:
        raise C.WinError(errors[0])
    return {"windows_moved": len(moved), "minimized_windows": "not_validated"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target")
    args = parser.parse_args()
    print(json.dumps(recover(args.target)))
