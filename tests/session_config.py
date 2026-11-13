#!/usr/bin/python3
"""Regression checks for layouts crossing the Vaela/Plasma session boundary."""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

source = Path(__file__).resolve().parents[1] / "session/vaela-plasmashell.in"
loader = importlib.machinery.SourceFileLoader("launcher", str(source))
spec = importlib.util.spec_from_loader(loader.name, loader)
launcher = importlib.util.module_from_spec(spec)
loader.exec_module(launcher)

LAYOUT = """[Containments][1]
plugin=org.kde.plasma.folder
wallpaperplugin=org.vaela.background

[Containments][1][Wallpaper][org.vaela.background][General]
Previous=org.kde.image
Fallback=/pictures/desktop.jpg

[Containments][1][Wallpaper][org.kde.image][General]
Image=/pictures/desktop.jpg
"""


class SessionConfigTest(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.base = Path(scratch.name)
        env = patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.base),
                                     "XDG_CONFIG_DIRS": "/etc/xdg"}, clear=True)
        env.start()
        self.addCleanup(env.stop)
        self.layout = self.base / "plasma-org.kde.plasma.desktop-appletsrc"
        self.private = self.base / "vaela-plasma"

    def test_normal_plasma_does_not_create_or_change_settings(self):
        original = LAYOUT.replace("wallpaperplugin=org.vaela.background", "wallpaperplugin=org.kde.image")
        self.layout.write_text(original)
        launcher.configure(False)
        self.assertEqual(self.layout.read_text(), original)
        self.assertFalse(self.private.exists())
        self.assertEqual(os.environ["XDG_CONFIG_HOME"], str(self.base))

    def test_upgrade_from_either_session_preserves_vaela_and_restores_plasma(self):
        for vaela in (False, True):
            with self.subTest(vaela=vaela):
                self.layout.write_text(LAYOUT)
                self.layout.chmod(0o600)
                (self.base / "plasmashellrc").write_text("[Panel]\nheight=64\n")
                launcher.configure(vaela)
                self.assertIn("wallpaperplugin=org.kde.image", self.layout.read_text())
                self.assertEqual((self.private / self.layout.name).read_text(), LAYOUT)
                self.assertEqual(self.layout.stat().st_mode & 0o777, 0o600)
                self.assertEqual((self.private / self.layout.name).stat().st_mode & 0o777, 0o600)
                self.assertEqual(self.layout.with_name(self.layout.name + ".pre-vaela-isolation").read_text(), LAYOUT)
                os.environ["XDG_CONFIG_HOME"] = str(self.base)

    def test_later_launch_preserves_each_sessions_edits(self):
        self.layout.write_text(LAYOUT)
        launcher.configure(True)
        (self.private / self.layout.name).write_text("private edits")
        self.layout.write_text("regular Plasma edits")
        os.environ["XDG_CONFIG_HOME"] = str(self.base)
        launcher.configure(True)
        self.assertEqual(self.layout.read_text(), "regular Plasma edits")
        self.assertEqual((self.private / self.layout.name).read_text(), "private edits")
        self.assertEqual(os.environ["XDG_CONFIG_HOME"], str(self.private))
        self.assertTrue(os.environ["XDG_CONFIG_DIRS"].startswith(str(self.base) + ":"))

    def test_private_mimeapps_merges_into_the_shared_file(self):
        self.private.mkdir()
        (self.base / "mimeapps.list").write_text("[Default Applications]\ntext/plain=kate.desktop;\n")
        (self.private / "mimeapps.list").write_text(
            "\n[Default Applications]\ntext/plain=other.desktop\nx-scheme-handler/codex=chatgpt.desktop\n")
        launcher.configure(True)
        self.assertFalse((self.private / "mimeapps.list").exists())
        merged = (self.base / "mimeapps.list").read_text()
        self.assertIn("text/plain=kate.desktop;\n", merged)
        self.assertNotIn("other.desktop", merged)
        self.assertIn("x-scheme-handler/codex=chatgpt.desktop\n", merged)

    def test_compositor_environment_overrides_stale_manager_marker(self):
        os.environ["VAELA_SESSION"] = "1"
        with patch.object(launcher.subprocess, "check_output", return_value=b"42\n"), \
                patch.object(Path, "read_bytes", return_value=b"XDG_CURRENT_DESKTOP=KDE\0"):
            self.assertNotIn(b"VAELA_SESSION", launcher.session_environment())

    def test_missing_previous_and_self_reference_fall_back_to_image(self):
        for text in (LAYOUT.replace("Previous=org.kde.image\n", ""),
                     LAYOUT.replace("Previous=org.kde.image", "Previous=org.vaela.background")):
            self.assertIn("wallpaperplugin=org.kde.image", launcher.restore_plasma_wallpaper(text))

    def test_orphaned_wallpaper_is_recovered_for_both_sessions(self):
        original = """[Containments][4][Wallpaper][org.kde.image][General]
Image=/pictures/north.png
PreviewImage=/pictures/north.png
FillMode=1

[Containments][43]
activityId=current-activity
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image
"""
        self.layout.write_text(original)
        self.private.mkdir()
        private_layout = self.private / self.layout.name
        private_layout.write_text(original)
        launcher.configure(False)
        for layout in (self.layout, private_layout):
            parsed = launcher.configparser.RawConfigParser()
            parsed.read(layout)
            section = "Containments][43][Wallpaper][org.kde.image][General"
            self.assertEqual(parsed[section]["Image"], "/pictures/north.png")
            self.assertEqual(parsed[section]["FillMode"], "1")
            self.assertEqual(layout.with_name(layout.name + ".pre-vaela-wallpaper-repair").read_text(), original)
        # A second launch must leave the repaired file and original backup alone.
        repaired = self.layout.read_text()
        launcher.configure(False)
        self.assertEqual(self.layout.read_text(), repaired)

    def test_restoring_image_plugin_recovers_its_saved_fallback(self):
        original = LAYOUT.replace(
            "[Containments][1][Wallpaper][org.kde.image][General]\nImage=/pictures/desktop.jpg\n", "")
        self.layout.write_text(original)
        launcher.configure(False)
        self.assertIn("wallpaperplugin=org.kde.image", self.layout.read_text())
        self.assertIn("[Containments][1][Wallpaper][org.kde.image][General]\nImage=/pictures/desktop.jpg", self.layout.read_text())

    def test_existing_wallpapers_and_ambiguous_orphans_are_preserved(self):
        desktop = "[Containments][43]\nplugin=org.kde.plasma.folder\nwallpaperplugin=org.kde.image\n"
        orphan = "[Containments][4][Wallpaper][org.kde.image][General]\nImage=/pictures/old.png\n"
        for original in (
            desktop + orphan + "[Containments][43][Wallpaper][org.kde.image][General]\nImage=/pictures/current.png\n",
            desktop + orphan + "[Containments][5][Wallpaper][org.kde.image][General]\nImage=/pictures/other.png\n",
            desktop.replace("org.kde.image", "org.kde.slideshow") + orphan,
            desktop.replace("org.kde.plasma.folder", "org.kde.panel") + orphan,
            desktop,
        ):
            with self.subTest(layout=original):
                self.layout.write_text(original)
                launcher.configure(False)
                self.assertEqual(self.layout.read_text(), original)
    def test_empty_image_keeps_desktop_options_and_ignores_live_donors(self):
        original = """[Containments][43]
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image
[Containments][43][Wallpaper][org.kde.image][General]
Image=
FillMode=2
[Containments][4][Wallpaper][org.kde.image][General]
Image=/pictures/old.png
FillMode=1
"""
        repaired = launcher.repair_image_wallpapers(original)
        self.assertIn("Image=/pictures/old.png\nFillMode=2", repaired)
        self.assertEqual(launcher.repair_image_wallpapers(repaired), repaired)
        # A second desktop's wallpaper must never be mistaken for an orphan.
        live = original + "[Containments][4]\nplugin=org.kde.plasma.folder\nwallpaperplugin=org.kde.image\n"
        self.assertEqual(launcher.repair_image_wallpapers(live), live)


if __name__ == "__main__":
    unittest.main()
