"""Launcher tests without network, graphics, or system installation."""

from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="probe-launcher-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.repo = self.directory / "downloaded game with spaces"
        self.project = self.repo / "game/3d-probe"
        self.project.mkdir(parents=True)
        (self.project / "project.godot").write_text("config_version=5\n")
        self.launcher = self.repo / "game/start.sh"
        shutil.copyfile(ROOT / "game/start.sh", self.launcher)
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        self.log = self.directory / "calls.txt"
        self.env = dict(os.environ, HOME=str(self.directory),
                        XDG_CACHE_HOME=str(self.directory / "cache with spaces"),
                        PATH=f"{self.bin}:/usr/bin:/bin", CALL_LOG=str(self.log))
        self.env.pop("GODOT_BIN", None)
        for name in ("godot", "godot4"):
            self.executable(self.bin / name, "#!/bin/sh\nprintf '4.6.stable.official\\n'\n")
        self.engine = self.directory / "editor with spaces"
        self.executable(self.engine, """#!/bin/sh
if [ "$1" = "--version" ]; then
    printf '%s\\n' "${FAKE_VERSION:-4.7.2.stable.official.test}"
    exit 0
fi
printf '<call>\\n' >> "$CALL_LOG"
printf '%s\\n' "$@" >> "$CALL_LOG"
case " $* " in
    *" --import "*)
        if [ "${FAKE_IMPORT:-}" = "error" ]; then echo 'SCRIPT ERROR: broken fixture'; fi
        if [ "${FAKE_IMPORT:-}" = "exit" ]; then exit 7; fi
        ;;
    *) exit "${FAKE_GAME_EXIT:-0}" ;;
esac
""")
        self.env["GODOT_BIN"] = str(self.engine)

    def executable(self, path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        path.chmod(0o755)

    def launch(self, *args):
        return subprocess.run(["/bin/bash", str(self.launcher), *args],
                              cwd=self.directory, env=self.env, text=True,
                              capture_output=True, timeout=15)

    def calls(self):
        return self.log.read_text().split("<call>\n")[1:] if self.log.exists() else []

    def test_shell_syntax(self):
        result = subprocess.run(["/bin/bash", "-n", str(self.launcher)],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_help_without_engine_or_project(self):
        shutil.rmtree(self.project)
        self.env["GODOT_BIN"] = "/missing"
        result = self.launch("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--setup-only", result.stdout)
        self.assertEqual(self.calls(), [])

    def test_paths_with_spaces_and_argument_boundaries(self):
        result = self.launch("--headless", "--quit-after", "60", "--", "argument with spaces")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [
            f"--headless\n--path\n{self.project}\n--editor\n--import\n--quit\n",
            f"--path\n{self.project}\n--headless\n--quit-after\n60\n--\nargument with spaces\n"])

    def test_setup_only_never_opens_game(self):
        self.assertEqual(self.launch("--setup-only").returncode, 0)
        self.assertEqual(len(self.calls()), 1)
        self.assertIn("--import", self.calls()[0])

    def test_setup_only_rejects_extra_arguments(self):
        self.assertNotEqual(self.launch("--setup-only", "--fullscreen").returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_missing_project_is_explained(self):
        (self.project / "project.godot").unlink()
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("весь архив", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_wrong_editor_version_is_rejected(self):
        self.env["FAKE_VERSION"] = "4.7.20.stable.official.test"
        self.assertNotEqual(self.launch().returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_missing_explicit_editor_is_not_silently_replaced(self):
        self.env["GODOT_BIN"] = "/missing"
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("GODOT_BIN", result.stderr)

    def test_existing_repository_editor_is_reused(self):
        self.env.pop("GODOT_BIN")
        destination = self.repo / ".tools/godot/godot"
        destination.parent.mkdir(parents=True)
        shutil.copy2(self.engine, destination)
        self.assertEqual(self.launch("--setup-only").returncode, 0)
        self.assertEqual(len(self.calls()), 1)

    def test_import_exit_stops_launch(self):
        self.env["FAKE_IMPORT"] = "exit"
        self.assertNotEqual(self.launch().returncode, 0)
        self.assertEqual(len(self.calls()), 1)

    def test_godot_script_error_with_zero_exit_stops_launch(self):
        self.env["FAKE_IMPORT"] = "error"
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SCRIPT ERROR", result.stderr)
        self.assertEqual(len(self.calls()), 1)

    def test_game_exit_code_is_preserved(self):
        self.env["FAKE_GAME_EXIT"] = "9"
        self.assertEqual(self.launch().returncode, 9)

    def test_unsupported_platform_and_architecture(self):
        for output in ("Darwin", "aarch64"):
            with self.subTest(output=output):
                script = "#!/bin/sh\nprintf 'Darwin\\n'\n" if output == "Darwin" else \
                    "#!/bin/sh\nif [ \"$1\" = -s ]; then echo Linux; else echo aarch64; fi\n"
                self.executable(self.bin / "uname", script)
                self.assertNotEqual(self.launch().returncode, 0)
                self.assertEqual(self.calls(), [])

    def test_download_failure_leaves_no_partial_installation(self):
        self.env.pop("GODOT_BIN")
        self.executable(self.bin / "curl", "#!/bin/sh\nexit 22\n")
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("скачать", result.stderr)
        self.assertEqual(list(Path(self.env["XDG_CACHE_HOME"]).rglob(".install.*")), [])
        self.assertEqual(self.calls(), [])

    def test_corrupt_cache_and_archive_are_not_executed(self):
        self.env.pop("GODOT_BIN")
        cache = Path(self.env["XDG_CACHE_HOME"]) / "10000-metres-probe/godot-4.7.2-linux-x86_64/godot"
        self.executable(cache, "#!/bin/sh\necho executed >> \"$CALL_LOG\"\n")
        self.executable(self.bin / "curl", """#!/bin/sh
while [ "$#" -gt 0 ]; do
    if [ "$1" = --output ]; then shift; printf 'bad archive' > "$1"; exit 0; fi
    shift
done
exit 1
""")
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Контрольная сумма", result.stderr)
        self.assertFalse(self.log.exists(), "An unverified executable ran")
        self.assertEqual(list(cache.parent.glob(".install.*")), [])


if __name__ == "__main__":
    unittest.main()
