# maria-nodejs

Async Node.js/TypeScript bindings for the bundled `sdk.exe` Maria agent. The package wraps the
CLI executable with a small JSON-RPC client and exposes a high-level `Maria`
class for streaming assistant responses.

## Quick start

```typescript
import { Maria } from "maria";

async function main() {
  const maria = new Maria();
  
  for await (const event of maria.start("Hello, Maria!")) {
    console.log(event);
  }
}

main().catch(console.error);
```

The async iterator yields structured events describing assistant messages and tool
calls emitted by the executable.

## Installation

```bash
npm install maria
```

## Requirements

- Node.js >= 18.0.0
- TypeScript >= 5.0.0 (for TypeScript users)

## Packaging the executable

Run the appropriate bundling script from the repository root to copy the
built `sdk.exe` into the package before building or publishing.

## License

Apache License 2.0
