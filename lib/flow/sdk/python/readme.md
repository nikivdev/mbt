# maria-python

Async Python bindings for the bundled `sdk.exe` Maria agent. The package wraps the
CLI executable with a small JSON-RPC client and exposes a high-level `Maria`
class for streaming assistant responses.

## Quick start

```python
import asyncio
from maria_python import Maria

async def main() -> None:
    maria = Maria()
    async for event in maria.stream("Hello, Maria!"):
        print(event)

asyncio.run(main())
```

The iterator yields structured events describing assistant messages and tool
calls emitted by the executable.

## Packaging the executable

Run `python scripts/bundle_maria_python.py` from the repository root to copy the
built `sdk.exe` into the package before building or publishing the wheel.
