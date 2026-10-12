"""Persist only the owned monitor's placement, relative to a physical anchor."""
import argparse
import json
import os
from pathlib import Path
import uuid


def load(filename):
    path = Path(filename)
    if not path.exists():
        return {"version": 1, "displays": {}}
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict) or data.get("version") != 1 or not isinstance(data.get("displays"), dict):
        raise ValueError("Invalid display layout file")
    return data


def overlaps(position, bounds):
    x, y = position
    return any(x < b["x"] + b["width"] and b["x"] < x + 1280
               and y < b["y"] + b["height"] and b["y"] < y + 720
               for b in bounds.values())


def position(filename, display_id, baseline):
    bounds = baseline["bounds"]
    default = (max(b["x"] + b["width"] for b in bounds.values()), 0)
    saved = load(filename)["displays"].get(display_id)
    if saved is None:
        return default, "not_saved"
    if (not isinstance(saved, dict) or saved.get("width") != 1280 or saved.get("height") != 720
            or any(type(saved.get(key)) is not int for key in ("offset_x", "offset_y"))):
        raise ValueError("Invalid saved virtual monitor placement")
    anchors = [r for r in baseline["topology"] if r["target_path"] == saved.get("anchor_target")]
    if len(anchors) != 1:
        return default, "anchor_unavailable"
    anchor = bounds[anchors[0]["source"]]
    candidate = (anchor["x"] + saved["offset_x"], anchor["y"] + saved["offset_y"])
    if any(not -32768 <= coordinate <= 32767 for coordinate in candidate):
        return default, "out_of_range"
    if overlaps(candidate, bounds):
        return default, "overlaps_physical_monitor"
    return candidate, "restored"


def remember(filename, display_id, target, rows, bounds):
    selected = [r for r in rows if r["target_path"] == target]
    if not selected:
        return "target_unavailable"
    if len(selected) != 1 or "#MTT1337#" not in target:
        raise ValueError("Cannot attribute virtual monitor placement")
    row = selected[0]
    physical = [r for r in rows if r["target_path"] != target]
    rect = bounds.get(row["source"])
    if (rect is None or rect["primary"] or (rect["width"], rect["height"]) != (1280, 720)
            or any(r["source"] == row["source"] for r in physical)):
        return "invalid_virtual_mode"
    physical_bounds = {r["source"]: bounds[r["source"]] for r in physical}
    if overlaps((rect["x"], rect["y"]), physical_bounds):
        return "overlaps_physical_monitor"
    anchors = [r for r in physical if bounds[r["source"]]["primary"]]
    if len(anchors) != 1:
        return "physical_anchor_unavailable"
    anchor = anchors[0]
    anchor_rect = bounds[anchor["source"]]
    data = load(filename)
    data["displays"][display_id] = {
        "anchor_target": anchor["target_path"],
        "offset_x": rect["x"] - anchor_rect["x"],
        "offset_y": rect["y"] - anchor_rect["y"],
        "width": 1280, "height": 720,
    }
    path = Path(filename)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    try:
        temporary.write_text(json.dumps(data, indent=2), encoding="utf-8")
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()
    return "saved"


if __name__ == "__main__":
    from prototype.windows_display import topology, monitor_bounds
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file")
    parser.add_argument("--display-id", default="default")
    parser.add_argument("--target", required=True)
    args = parser.parse_args()
    print(json.dumps({"virtual_placement": remember(args.file, args.display_id, args.target,
                                                    topology(), monitor_bounds())}))
