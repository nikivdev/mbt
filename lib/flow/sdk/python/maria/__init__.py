import importlib.resources as resources
import asyncio
import platform
import maria.events
from typing import AsyncGenerator


def _get_system() -> str:
    return f"{platform.system().lower()}-{platform.machine().lower()}"


class Maria:
    async def start(
        self, prompt: str
    ) -> AsyncGenerator[maria.events.Notification, None]:
        system = _get_system()
        resource = resources.files("maria").joinpath("bin").joinpath(f"{system}.exe")
        with resources.as_file(resource) as executable_path:
            process = await asyncio.create_subprocess_exec(
                executable_path,
                "exec",
                prompt,
                stdout=asyncio.subprocess.PIPE,
            )
            assert process.stdout is not None

            # Read stdout asynchronously line by line
            while True:
                line = await process.stdout.readline()
                if not line:
                    break
                yield maria.events.notification.validate_json(line)

            status = await process.wait()
            if status != 0:
                raise RuntimeError(f"Maria process failed to start: {status}")
