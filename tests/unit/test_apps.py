import hashlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("apps", ROOT / "scripts/lib/apps.py")
apps = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(apps)


def archive(member="run"):
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode="w:gz") as bundle:
        script = b'#!/bin/sh\nprintf "%s\\n" "$@"\n'
        entry = tarfile.TarInfo(member)
        entry.size = len(script)
        entry.mode = 0o755
        bundle.addfile(entry, io.BytesIO(script))
    return data.getvalue()


class AppsTest(unittest.TestCase):
    def test_lifecycle_and_failed_upgrade(self):
        with tempfile.TemporaryDirectory() as temp:
            env = dict(os.environ, XDG_DATA_HOME=temp)
            directory = Path(temp) / "corebrum/apps/example/depth"
            app = {"id": "example/depth"}
            payload = archive()
            target = {"url": "https://example.org/app.tar.gz",
                      "sha256": hashlib.sha256(payload).hexdigest()}
            with patch.object(apps, "open_https", return_value=io.BytesIO(payload)):
                apps.install(app, {"version": "1.0.0", "entry": "run"}, target, directory)
            with patch.object(apps, "open_https", return_value=io.BytesIO(b"invalid")):
                with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
                    apps.install(app, {"version": "2.0.0", "entry": "run"}, target, directory)
            with patch.object(apps, "open_https", return_value=io.BytesIO(payload)):
                with self.assertRaisesRegex(ValueError, "Missing executable entry point"):
                    apps.install(app, {"version": "2.0.0", "entry": "missing"}, target, directory)

            def cli(*args):
                return subprocess.check_output(
                    [ROOT / "scripts/corebrum.sh", "apps", *args], env=env, text=True)

            self.assertEqual(cli("list"), "example/depth\t1.0.0\n")
            self.assertEqual(cli("run", "example/depth", "--", "--test", "a b"), "--test\na b\n")
            with patch.object(apps, "open_https") as download:
                apps.install(app, {"version": "1.0.0", "entry": "run"}, target, directory)
                download.assert_not_called()
            with patch.object(apps, "open_https", return_value=io.BytesIO(payload)):
                apps.install(app, {"version": "2.0.0", "entry": "run"}, target, directory)
            self.assertEqual(cli("list"), "example/depth\t2.0.0\n")
            cli("remove", "example/depth")
            self.assertEqual(cli("list"), "")

    def test_archive_rejects_parent_path(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "release.tar.gz"
            path.write_bytes(archive("../run"))
            with self.assertRaisesRegex(ValueError, "Invalid app-relative path"):
                apps.extract_archive(path, Path(temp) / "app")

    def test_compatible_release_selection(self):
        app = {"id": "example/depth", "releases": [
            {"version": "1.9.0", "targets": [{"ubuntu": "24.04", "arch": "arm64"}]},
            {"version": "1.10.0", "targets": [{"ubuntu": "24.04", "arch": "arm64"}]},
            {"version": "2.0.0", "targets": [{"ubuntu": "26.04", "arch": "arm64"}]},
        ]}
        with patch.object(apps.platform, "freedesktop_os_release",
                          return_value={"ID": "ubuntu", "VERSION_ID": "24.04"}), \
             patch.object(apps.platform, "machine", return_value="aarch64"):
            self.assertEqual(apps.choose_release(app, "")[0]["version"], "1.10.0")
            self.assertEqual(apps.choose_release(app, "1.9.0")[0]["version"], "1.9.0")
            with self.assertRaisesRegex(ValueError, "No compatible release"):
                apps.choose_release(app, "2.0.0")


if __name__ == "__main__":
    unittest.main()
