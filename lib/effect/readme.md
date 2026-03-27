# Effect (MoonBit) - Traced Native POC

Minimal native Effect core with **always-on mutation tracing**.

## Core idea

- `Effect[R, E, A]` is a function `R -> Result[A, E]` wrapped in async.
- Mutations should go through **TracedRef**, which records changes into a ring buffer.
- Tracing is always-on and low overhead (no IO by default).

## Tracing

Create a `TraceBuffer` and pass it through your environment or keep it as a Ref:

```moonbit
let trace = Ref::new(@effect.TraceBuffer::new(512))
```

All writes through `TracedRef` are recorded:

```moonbit
let counter = @effect.TracedRef::new("counter", 0, trace)
@effect.TracedRef::update(counter, x => x + 1)
@effect.TracedRef::set(counter, 10)

let events = @effect.snapshot(trace)
inspect(events)
```

## Effect usage

```moonbit
import "nikivdev/moonbit/lib/effect"

struct Env { trace : Ref[@effect.TraceBuffer] }

fn program() -> @effect.Effect[Env, String, String] {
  @effect.Effect::succeed("ok")
}
```

## Notes

- Location tagging is supported via `set_at` / `update_at` but not auto-filled yet.
- This is a minimal native core; no runtime, fibers, or scopes.
