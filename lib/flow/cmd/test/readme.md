# test

Runner for a single prompt against Maria, producing a JSONL activity log you can later inspect or convert to Markdown.

## Usage

```bash
moon run cmd/test -- --prompt-file <prompt-file> [--log-file <log-file>]
```

Arguments:
- `--prompt-file <path>`: Required. Path to a text/markdown file containing the initial prompt fed to Maria.
- `--log-file <path>`: Optional. Destination for the JSONL log. If omitted, a file named `maria_test_log_<timestamp>.jsonl` is created in the current working directory. The timestamp uses the system clock and is formatted as a plain date time (e.g. `2025-10-21T04:42:38`).

Exit codes: This tool prints errors for invalid arguments and exits early; it does not currently set specialized non‑zero codes beyond the runtime defaults.

## Example

Create a prompt file:

```bash
cat > prompt.md <<'EOF'
You are an assistant; respond briefly.
What is the capital of France?
EOF
```

Run the test:

```bash
moon run cmd/test -- --prompt-file prompt.md
# Produces: maria_test_log_2025-10-21T04:42:38.jsonl (name will vary)
```

Specify a custom log file:

```bash
moon run cmd/test -- --prompt-file prompt.md --log-file session.jsonl
```

## Log Format

The log file is line‑delimited JSON (JSONL). Each non‑blank line is one event produced during the session. Selected event types are later consumable by the `jsonl2md` converter:
- `MessageAdded`: User / assistant / system / tool messages as they are added.
- `RequestCompleted`: Assistant responses (may include tool calls).
- `PostToolCall`: Output from a tool invocation.

## Converting Log to Markdown

Use the companion tool in `cmd/jsonl2md`:

```bash
moon run cmd/jsonl2md -- maria_test_log_2025-10-21T04:42:38.jsonl --output session.md
```

If `--output` is omitted, `jsonl2md` writes `<input-stem>.md` next to the source file.

### Sample Conversion

Given a trimmed JSONL (illustrative only):

```jsonl
{"msg":"MessageAdded","message":{"role":"user","content":[{"type":"text","text":"What is the capital of France?"}]}}
{"msg":"RequestCompleted","message":{"role":"assistant","content":"Paris is the capital of France."}}
```

Conversion produces Markdown like:

````markdown
# 1 User: What is the capital of France?

What is the capital of France?

# 2 Assistant: Paris is the capital of France.

Paris is the capital of France.
````

## Tips

- Keep prompts small and focused; extremely large prompts will impact response latency.
- Preserve the generated JSONL log for reproducibility or regression comparisons.
- You can version logs or diffs by checking them into a separate directory ignored by VCS.

## Future Improvements

Potential enhancements: structured exit codes, streaming output, log schema docs, autosummary after run.
