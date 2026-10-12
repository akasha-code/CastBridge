"""Configure the owned virtual target using explicit original physical modes."""
import argparse
import ctypes as C
import json
import struct
from pathlib import Path as FilePath

from prototype.windows_display import Mode, Path, monitor_bounds, physical_unchanged, raw_query, target_name, topology
from prototype.display_layout import position as saved_position


class IndependentSourceUnavailable(RuntimeError):
    pass


def snapshot(filename):
    paths, modes = raw_query()
    payload = {"paths": [bytes(p).hex() for p in paths],
               "modes": [bytes(m).hex() for m in modes],
               "names": [target_name(p) for p in paths],
               "topology": topology(), "bounds": monitor_bounds()}
    FilePath(filename).write_text(json.dumps(payload, indent=2), encoding="utf-8")


def adapter(luid):
    return luid.high, luid.low


def configuration(baseline, extend, placement=None):
    original_paths = [Path.from_buffer_copy(bytes.fromhex(value)) for value in baseline["paths"]]
    original_modes = [Mode.from_buffer_copy(bytes.fromhex(value)) for value in baseline["modes"]]
    original_rows = baseline["topology"]
    original_names = {row["target_path"] for row in original_rows}
    active, _ = raw_query()
    active_by_name = {target_name(path): path for path in active}
    if not original_names.issubset(active_by_name):
        raise RuntimeError("A physical target disappeared; refusing configuration")
    extra = set(active_by_name) - original_names
    if (extend and (len(extra) != 1 or not all("#MTT1337#" in name for name in extra))) or (not extend and extra):
        raise RuntimeError("Unexpected targets; cannot establish session ownership")
    paths, modes = [], []
    used_sources = set()
    for original, name in zip(original_paths, baseline["names"]):
        current = active_by_name[name]
        copy = Path.from_buffer_copy(bytes(original))
        copy.source.adapter, copy.source.id = current.source.adapter, current.source.id
        copy.target.adapter, copy.target.id = current.target.adapter, current.target.id
        for section, index, kind in ((copy.source, original.source.mode, 1), (copy.target, original.target.mode, 2)):
            if index == 0xFFFFFFFF:
                section.mode = index
                continue
            if index >= len(original_modes) or original_modes[index].kind != kind:
                raise RuntimeError("Invalid baseline mode reference")
            mode = Mode.from_buffer_copy(bytes(original_modes[index]))
            mode.adapter, mode.id = section.adapter, section.id
            section.mode = len(modes)
            modes.append(mode)
        paths.append(copy)
        used_sources.add((adapter(copy.source.adapter), copy.source.id))
    if extend:
        name = next(iter(extra))
        all_paths, _ = raw_query(1)
        available = [path for path in all_paths if path.target.available
                     and target_name(path) == name
                     and (adapter(path.source.adapter), path.source.id) not in used_sources]
        if not available:
            raise IndependentSourceUnavailable("No independent source is available for the virtual target")
        virtual = Path.from_buffer_copy(bytes(available[0]))
        virtual.flags = 1
        mode = Mode()
        mode.kind, mode.id, mode.adapter = 1, virtual.source.id, virtual.source.adapter
        right = max(rect["x"] + rect["width"] for rect in baseline["bounds"].values())
        x, y = placement if placement is not None else (right, 0)
        payload = struct.pack("<IIIii", 1280, 720, 4, x, y)
        C.memmove(C.addressof(mode) + Mode.data.offset, payload, len(payload))
        virtual.source.mode, virtual.target.mode = len(modes), 0xFFFFFFFF
        virtual.target.rotation, virtual.target.scaling = 1, 1
        virtual.target.refresh.numerator, virtual.target.refresh.denominator = 60, 1
        modes.append(mode)
        paths.append(virtual)
    return (Path * len(paths))(*paths), (Mode * len(modes))(*modes)


def apply(filename, extend, layout_file=None, display_id="default"):
    baseline = json.loads(FilePath(filename).read_text(encoding="utf-8"))
    user = C.WinDLL("user32")
    placement = None
    if extend and layout_file:
        placement, reason = saved_position(layout_file, display_id, baseline)
        print(json.dumps({"placement_selection": reason, "position": placement}))
    try:
        paths, modes = configuration(baseline, extend, placement)
    except IndependentSourceUnavailable:
        if not extend:
            raise
        # Cloned indirect targets may not expose another source until Windows
        # allocates an extended topology. Restore explicit physical modes next.
        result = user.SetDisplayConfig(0, None, 0, None, 0x44)
        if result:
            raise C.WinError(result)
        result = user.SetDisplayConfig(0, None, 0, None, 0x84)
        if result:
            raise C.WinError(result)
        print(json.dumps({"source_assignment": "Windows extended topology", "physical_verification": "pending_explicit_modes"}))
        paths, modes = configuration(baseline, extend, placement)
    # Validate first, without saving to the persistent configuration database.
    flags = 0x20 | (0x400 if extend else 0)
    result = user.SetDisplayConfig(len(paths), paths, len(modes), modes, flags | 0x40)
    if result:
        raise C.WinError(result)
    result = user.SetDisplayConfig(len(paths), paths, len(modes), modes, flags | 0x80)
    if result:
        raise C.WinError(result)
    current = topology()
    if not physical_unchanged(baseline["topology"], current):
        raise RuntimeError("Physical mode verification failed after configuration")
    bounds_by_source = monitor_bounds()
    current_by_name = {row["target_path"]: row for row in current}
    for old in baseline["topology"]:
        actual = bounds_by_source[current_by_name[old["target_path"]]["source"]]
        expected = baseline["bounds"][old["source"]]
        if actual != expected:
            raise RuntimeError("Physical bounds or primary monitor changed")
    if extend:
        original_names = {row["target_path"] for row in baseline["topology"]}
        added = [row for row in current if row["target_path"] not in original_names]
        if len(added) != 1 or added[0]["source"] in {row["source"] for row in current if row["target_path"] in original_names}:
            raise RuntimeError("Virtual target is still cloned")
        bounds = bounds_by_source.get(added[0]["source"])
        if bounds is None or (bounds["width"], bounds["height"]) != (1280, 720):
            raise RuntimeError("Unexpected virtual capture bounds")
        if placement is not None and (bounds["x"], bounds["y"]) != placement:
            raise RuntimeError("Windows did not apply the requested virtual placement")
        print(json.dumps({"extended": True, "physical_modes_preserved": True, "virtual_bounds": bounds}))
    else:
        print(json.dumps({"physical_modes_restored": True}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("snapshot", "extend", "restore"))
    parser.add_argument("file")
    parser.add_argument("--layout-file")
    parser.add_argument("--display-id", default="default")
    args = parser.parse_args()
    if args.action == "snapshot":
        snapshot(args.file)
    else:
        apply(args.file, args.action == "extend", args.layout_file, args.display_id)
