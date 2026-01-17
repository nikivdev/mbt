# HTTP Server

This is a simple HTTP server that exposes an endpoint for sending messages to
the Maria agent and another endpoint for receiving server-sent events (SSE) from
the agent. It comes with a simple HTML frontend for testing the API.

## Run

From the root directory of the repository, run:

```bash
moon run cmd/server -- --port 8080 --serve cmd/server
```

Then open `http://localhost:8080` in your web browser to access the HTML
frontend.

## `POST /v1/message`

Request:

```json
{
  "message": {
    "role": "user",
    "content": "Hello, world!"
  }
}
```

## `GET /v1/events`

```plaintext
event: maria
data: <json>
```

Example JSON objects:

```jsonl
{"level":30,"pid":79372,"msg":"TokenCounted","hostname":"localhost","time":1762763278519,"tag":"server","token_count":16984}
{"level":30,"pid":79372,"msg":"ContextPruned","hostname":"localhost","time":1762763278519,"tag":"server","origin_token_count":16984,"pruned_token_count":16984}
```

For concrete JSON object formats, refer to the code of `maria`.

## `GET /v1/moonbit/modules`

Returns the list of MoonBit modules in the server's working directory.

Response:

```json
{
  "modules": [
    {
      "path": "/path/to/moonbit/module",
      "name": "example-module",
      "version": "1.0.0",
      "description": "An example module."
    }
  ]
}
```

## `POST /v1/moonbit/publish`

Runs `moon publish` in the server's working directory.

```json
{
  "module": {
    "path": "/path/to/moonbit/module"
  }
}
```

If it fails to find such a module, returns 404 Not Found:

```json
{
  "error": {
    "code": -1,
    "message": "No MoonBit module found in path."
  }
}
```

If successful, returns 201 Created:

```json
{
  "module": {
    "name": "example-module",
    "version": "1.0.0",
    "description": "An example module.",
  },
  "process": {
    "status": 0,
    "stdout": "Published successfully.",
    "stderr": ""
  }
}
```

If failed, returns 500 Internal Server Error:

```json
{
  "error": {
    "code": -1,
    "message": "Failed to publish the module.",
    "metadata": {
      "module": {
        "name": "example-module",
        "version": "1.0.0",
        "description": "An example module.",
      },
      "process": {
        "status": 1,
        "stdout": "",
        "stderr": "Error: Failed to publish."
      }
    }
  },
}
```
