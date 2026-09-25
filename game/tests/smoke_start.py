"""Verify a fresh source download and offline relaunch with the real Godot binary."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]


def executable(path, text):
    path.write_text(text)
    path.chmod(0o755)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path,
                        help="Use a previously downloaded official ZIP instead of network")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="deck-launch-smoke-") as temporary:
        directory = Path(temporary)
        repo = directory / "downloaded sources with spaces"
        repo.mkdir()
        (repo / "game").mkdir()
        shutil.copy2(ROOT / "game/start.sh", repo / "game/start.sh")
        shutil.copytree(ROOT / "game/3d-probe", repo / "game/3d-probe",
                        ignore=shutil.ignore_patterns(".godot", "build", "evidence"))
        commands = directory / "bin"
        commands.mkdir()
        for name in ("godot", "godot4"):
            executable(commands / name, "#!/bin/sh\nexit 1\n")
        home = directory / "home"
        home.mkdir()
        env = dict(os.environ, HOME=str(home), XDG_CACHE_HOME=str(home / ".cache"),
                   XDG_CONFIG_HOME=str(home / ".config"), XDG_DATA_HOME=str(home / ".local/share"),
                   PATH=f"{commands}:{os.environ['PATH']}")
        env.pop("GODOT_BIN", None)
        if args.archive:
            env["GODOT_TEST_ARCHIVE"] = str(args.archive.resolve(strict=True))
            executable(commands / "curl", """#!/bin/sh
while [ "$#" -gt 0 ]; do
    if [ "$1" = --output ]; then shift; cp "$GODOT_TEST_ARCHIVE" "$1"; exit $?; fi
    shift
done
exit 1
""")

        def run(*options):
            result = subprocess.run(["/bin/bash", str(repo / "game/start.sh"), *options],
                                    cwd=directory, env=env, text=True,
                                    capture_output=True, timeout=700)
            print(result.stdout, end="", flush=True)
            if result.returncode or "ERROR:" in result.stderr:
                raise RuntimeError(f"Launcher failed ({result.returncode}): {result.stderr}")
            return result

        first = run("--setup-only")
        assert "Скачиваю официальный" in first.stdout, "Fresh cache path was not exercised"
        cached = home / ".cache/10000-metres-probe/godot-4.7.2-linux-x86_64/godot"
        assert cached.is_file(), "Verified engine was not cached"
        assert not list(cached.parent.glob(".install.*")), "Installation left temporary files"
        executable(commands / "curl", "#!/bin/sh\necho 'Offline: unexpected download' >&2\nexit 42\n")
        second = run("--headless", "--quit-after", "60")
        assert "Скачиваю официальный" not in second.stdout, "Cached run tried downloading again"
        print("PASS: clean sources, first installation, verified cache, offline native headless launch; no system changes.")


if __name__ == "__main__":
    main()
