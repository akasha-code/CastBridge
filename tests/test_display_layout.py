import json
from pathlib import Path
import tempfile
import unittest

from prototype.display_layout import load, position, remember


class DisplayLayoutTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.file = Path(self.directory.name) / "layout.json"
        self.physical = dict(target_path="physical", source="p")
        self.virtual = dict(target_path="owned#MTT1337#target", source="v")
        self.bounds = {"p": dict(x=0, y=0, width=1920, height=1080, primary=True),
                       "v": dict(x=-1280, y=100, width=1280, height=720, primary=False)}
        self.baseline = {"topology": [self.physical], "bounds": {"p": self.bounds["p"]}}

    def save(self):
        return remember(self.file, "cast1", self.virtual["target_path"],
                        [self.physical, self.virtual], self.bounds)

    def test_remembers_left_side_position_across_source_renumbering(self):
        self.assertEqual(self.save(), "saved")
        baseline = {"topology": [dict(self.physical, source="new")],
                    "bounds": {"new": self.bounds["p"]}}
        self.assertEqual(position(self.file, "cast1", baseline), ((-1280, 100), "restored"))
        self.assertFalse(list(self.file.parent.glob("*.tmp")))

    def test_position_follows_physical_anchor(self):
        self.save()
        self.baseline["bounds"] = {"p": dict(self.bounds["p"], x=500, y=200)}
        self.assertEqual(position(self.file, "cast1", self.baseline), ((-780, 300), "restored"))

    def test_overlap_after_setup_change_uses_safe_default(self):
        self.save()
        self.baseline["bounds"]["other"] = dict(x=-1920, y=0, width=1920, height=1080, primary=False)
        self.assertEqual(position(self.file, "cast1", self.baseline),
                         ((1920, 0), "overlaps_physical_monitor"))

    def test_missing_anchor_uses_safe_default(self):
        self.save()
        self.baseline["topology"] = [dict(self.physical, target_path="replacement")]
        self.assertEqual(position(self.file, "cast1", self.baseline), ((1920, 0), "anchor_unavailable"))

    def test_preferences_are_separate_for_each_receiver(self):
        self.save()
        self.assertEqual(position(self.file, "cast2", self.baseline), ((1920, 0), "not_saved"))
        remember(self.file, "cast2", self.virtual["target_path"], [self.physical, self.virtual], self.bounds)
        self.assertEqual(set(load(self.file)["displays"]), {"cast1", "cast2"})

    def test_refuses_to_remember_physical_or_cloned_target(self):
        with self.assertRaises(ValueError):
            remember(self.file, "cast1", "physical", [self.physical], self.bounds)
        self.assertEqual(remember(self.file, "cast1", self.virtual["target_path"],
                                  [self.physical, dict(self.virtual, source="p")], self.bounds),
                         "invalid_virtual_mode")
        self.assertFalse(self.file.exists())

    def test_does_not_replace_position_with_unavailable_target(self):
        self.save()
        original = self.file.read_bytes()
        self.assertEqual(remember(self.file, "cast1", self.virtual["target_path"],
                                  [self.physical], {"p": self.bounds["p"]}), "target_unavailable")
        self.assertEqual(self.file.read_bytes(), original)

    def test_invalid_layout_is_reported(self):
        self.file.write_text(json.dumps({"version": 2, "displays": {}}))
        with self.assertRaises(ValueError):
            position(self.file, "cast1", self.baseline)
