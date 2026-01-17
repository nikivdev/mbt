from pathlib import Path
import subprocess


def publish():
    local_moon = Path(".moon")
    local_credentials = local_moon / "credentials.json"
    if not local_credentials.exists():
        raise FileNotFoundError("./.moon/credentials.json not found")
    publish_directory = Path("publish")
    subprocess.run(
        ["moon", "publish"],
        check=True,
        cwd=publish_directory,
        env={"MOON_HOME": str(local_moon.resolve())},
    )


if __name__ == "__main__":
    publish()
