#!/usr/bin/env python3

"""Copy the built sdk.exe into the Python package for distribution."""

import shutil
from pathlib import Path
import subprocess
import platform


def copy_file(src: Path, dest: Path):
    print(f"COPY {src} to {dest}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, dest)


def main():
    target = f"{platform.system().lower()}-{platform.machine().lower()}"
    subprocess.run(["moon", "build", "--target", "native", "--release"], check=True)
    main_exe = (
        Path.cwd() / "target" / "native" / "release" / "build" / "sdk" / "sdk.exe"
    )
    copy_file(main_exe, Path("sdk") / "python" / "maria" / "bin" / f"{target}.exe")
    copy_file(main_exe, Path("sdk") / "nodejs" / "bin" / f"{target}.exe")
    copy_file(
        main_exe,
        Path("sdk") / "java" / "src" / "main" / "resources" / "bin" / f"{target}.exe",
    )


if __name__ == "__main__":
    main()
