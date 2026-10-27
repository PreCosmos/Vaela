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

    def test_compositor_environment_overrides_stale_manager_marker(self):
        os.environ["VAELA_SESSION"] = "1"
        with patch.object(launcher.subprocess, "check_output", return_value=b"42\n"), \
                patch.object(Path, "read_bytes", return_value=b"XDG_CURRENT_DESKTOP=KDE\0"):
            self.assertNotIn(b"VAELA_SESSION", launcher.session_environment())

    def test_missing_previous_and_self_reference_fall_back_to_image(self):
        for text in (LAYOUT.replace("Previous=org.kde.image\n", ""),
                     LAYOUT.replace("Previous=org.kde.image", "Previous=org.vaela.background")):
            self.assertIn("wallpaperplugin=org.kde.image", launcher.restore_plasma_wallpaper(text))


if __name__ == "__main__":
    unittest.main()
