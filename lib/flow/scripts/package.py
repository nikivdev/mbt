from pathlib import Path
import shutil
import subprocess
import os

source = [
    "agent",
    "clock",
    "file",
    "internal",
    "job",
    "model",
    "openai",
    "prompt",
    "todo",
    "tool",
    "tools",
    "LICENSE",
    "maria.mbt",
    "moon.pkg.json",
    "moon.mod.json",
    "pkg.generated.mbti",
    "README.md",
]


def remove_tests(directory: Path):
    print(f"RM-T D {directory}")
    for item in directory.iterdir():
        if item.is_dir():
            remove_tests(item)
        elif item.name.endswith("_test.mbt"):
            print(f"RM-T F {item}")
            item.unlink()


def remove_directory_if_exists(directory: Path):
    if directory.exists() and directory.is_dir():
        shutil.rmtree(directory)


def remove_file_if_exists(file_path: Path):
    if file_path.exists() and file_path.is_file():
        file_path.unlink()


def package():
    publish_directory = Path("publish")
    if publish_directory.exists():
        shutil.rmtree(publish_directory)
    else:
        publish_directory.mkdir()
    for item in source:
        src_path = Path(item)
        dest_path = publish_directory / item
        if src_path.is_dir():
            shutil.copytree(src_path, dest_path, dirs_exist_ok=True)
        else:
            shutil.copy2(src_path, dest_path)
    shutil.rmtree(publish_directory / "prompt" / "system-prompt")
    subprocess.run(["moon", "check"], cwd=publish_directory, check=True)
    test_env = os.environ.copy()
    if "OPENAI_API_KEY" in test_env:
        del test_env["OPENAI_API_KEY"]
    subprocess.run(["moon", "test"], cwd=publish_directory, check=True, env=test_env)
    remove_directory_if_exists(publish_directory / "__trajectories__")
    remove_directory_if_exists(
        publish_directory / "internal" / "tiktoken" / "__snapshot__"
    )
    remove_directory_if_exists(
        publish_directory / "internal" / "tiktoken" / ".pytest_cache"
    )
    remove_directory_if_exists(publish_directory / "internal" / "tiktoken" / ".venv")
    remove_directory_if_exists(publish_directory / "internal" / "tiktoken" / "scripts")
    remove_file_if_exists(
        publish_directory / "internal" / "tiktoken" / ".python-version"
    )
    remove_file_if_exists(publish_directory / "internal" / "tiktoken" / ".gitignore")
    remove_file_if_exists(publish_directory / "internal" / "tiktoken" / "uv.lock")
    remove_file_if_exists(
        publish_directory / "internal" / "tiktoken" / "pyproject.toml"
    )
    remove_tests(publish_directory)
    subprocess.run(["moon", "check"], cwd=publish_directory, check=True)


if __name__ == "__main__":
    package()
