# jsonl2md

Converting JSONL files produced by `cmd/test` into Markdown format for easier
inspection.

> [!NOTE]
> This tool is currently NOT able to parse the JSONL format log produced
> by `main.exe`, which is serves an unified executable to interactive cli and SDK
> server.

```bash
moon run cmd/jsonl2md path/to/input.jsonl --output path/to/output.md
```

## Input Format (JSONL)

Each line is an independent JSON object. Empty lines are ignored. The tool currently responds to three `msg` variants:

1. `MessageAdded`
	- Fields: `msg`, `message.role`, `message.content` (array of objects with `{ "type": "text", "text": ... }`)
	- Rendered as: `# <n> <Role>: <First non-blank content line>` followed by the full textual content.
2. `RequestCompleted`
	- Fields: `msg`, `message.role`, `message.content` (string), optional `message.tool_calls` (array)
	- Content trimmed of surrounding whitespace. Title line uses first non-blank line of `content`. If blank, just role.
	- Each tool call with `{ "function": { "name": <name>, "arguments": <json-string> } }` is rendered as a second‑level heading: `## Tool call argument: <name>` plus a formatted argument body.
3. `PostToolCall`
	- Fields: `msg`, `name`, `text`, optional `result` or `error`
	- Rendered as: `# <n> ✓ Tool call result: <name>` (or `# <n> ❌ Tool call error: <name>` if error) and a fenced code block containing `text`.

Messages are numbered sequentially starting from 1 (internal counter starts at 0 and increments after each rendered block).

## Example

Input (`example.log.jsonl`):

```jsonl
{"msg":"MessageAdded","message":{"role":"user","content":[{"type":"text","text":"Hello, how are you?"}]}}
{"msg":"RequestCompleted","message":{"role":"assistant","content":"I am fine, thank you!\nHere is more detail.","tool_calls":[{"id":"tool_call_1","function":{"name":"get_weather","arguments":"{\"location\": \"New York\"}"}}]}}
{"msg":"PostToolCall","name":"get_weather","text":"{\n  \"location\": \"New York\",\n  \"temp_c\": 24\n}"}
```

Output (`example.log.md`):

````markdown
# 1 User: Hello, how are you?

Hello, how are you?

# 2 Assistant: I am fine, thank you!

I am fine, thank you!
Here is more detail.

## Tool call argument: <get_weather>

<location>
  New York
</location>

# 3 ✓ Tool call result: <get_weather>

```
{
  "location": "New York",
  "temp_c": 24
}
```

````

## Notes

- The tool creates the output directory if missing.
- If `--output` is omitted, the output path defaults to `<stem(input_path)>.md`.
- Lines that fail JSON parsing are skipped with a warning.
- Tool call arguments are first attempted to be parsed as JSON; if parsing fails, raw text is emitted.
