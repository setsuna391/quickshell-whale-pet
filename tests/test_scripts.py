import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ModelScriptTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.config = self.home / ".config/dsh-pet/config.json"
        self.config.parent.mkdir(parents=True)
        fake_qs = self.home / "qs"
        fake_qs.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        fake_qs.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.home) + ":" + os.environ["PATH"])

    def run_model(self):
        return subprocess.run([str(ROOT / "model.sh"), "xiaoke"], env=self.env,
                              text=True, capture_output=True, check=True)

    def test_atomic_model_update_preserves_other_settings(self):
        self.config.write_text('{"sound":false,"model":"old"}', encoding="utf-8")
        self.config.chmod(0o640)
        self.run_model()
        self.assertEqual(json.loads(self.config.read_text()),
                         {"sound": False, "model": "characters/xiaoke.png"})
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o640)

    def test_invalid_config_is_not_overwritten(self):
        self.config.write_text("{broken", encoding="utf-8")
        self.run_model()
        self.assertEqual(self.config.read_text(), "{broken")

    def test_symlink_is_not_replaced(self):
        target = self.home / "target.json"
        target.write_text('{"model":"old"}', encoding="utf-8")
        self.config.symlink_to(target)
        self.run_model()
        self.assertTrue(self.config.is_symlink())
        self.assertEqual(json.loads(target.read_text())["model"], "old")


if __name__ == "__main__":
    unittest.main()
