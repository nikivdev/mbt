# Agent Package

The `agent` package provides a high-level interface for building AI agents that
can interact with Large Language Models (LLMs) and execute tools. It manages
conversation history, tool execution, context pruning, and event-driven
monitoring of the agent lifecycle.

## Overview

An `Agent` is an autonomous entity that:

- Sends messages to an LLM and receives responses
- Executes tools based on LLM requests
- Manages conversation history and context
- Emits events throughout its lifecycle for monitoring and debugging
- Handles token counting and automatic context pruning

## Quick Start

### Creating an Agent

```moonbit
///|
let model : @model.Model = @model.new(
  api_key=try! @os.getenv("OPENAI_API_KEY").unwrap(),
  base_url="https://openrouter.ai/api/v1",
  name="x-ai/grok-code-fast-1",
  safe_zone_tokens=200000,
)

///|
async test "basic-example" {
  // Create the agent
  let agent = @agent.new(model, cwd=@os.cwd())
  // Add a user message
  agent.add_message(@openai.user_message(content="Hello, what can you do?"))
  // Start the conversation
  agent.start()
}
```

### Adding Tools

Tools extend what the agent can do beyond simple conversation. Here's how to
create a simple addition tool and add it to the agent:

```moonbit
///|
let add_numbers_schema : @tool.JsonSchema = @tool.JsonSchema::from_json({
  "type": "object",
  "properties": {
    "a": { "type": "number", "description": "First number" },
    "b": { "type": "number", "description": "Second number" },
  },
  "required": ["a", "b"],
})

///|
let add_numbers_tool : @tool.Tool[String] = @tool.new(
  name="add_numbers",
  description="Add two numbers together",
  schema=add_numbers_schema,
  ToolFn(args => {
    guard args is { "a": Number(a, ..), "b": Number(b, ..), .. } else {
      return @tool.error("Invalid arguments")
    }
    @tool.ok("The result of \{a} + \{b} is \{a + b}")
  }),
)

///|
async test "adding-tools" {
  let agent = @agent.new(model, cwd=@os.cwd())
  // Add the tool to the agent
  agent.add_tool(add_numbers_tool)
}
```

## Agent Lifecycle

The agent follows a specific lifecycle when processing a conversation:

1. **Initialization** - Agent is created with model configuration and working directory
2. **Tool Registration** - Tools are added to the agent's capabilities
3. **Message Queue** - User messages are added to the queue via `add_message()`
4. **Conversation Start** - `start()` is called, triggering `PreConversation` event
5. **Request Loop**:
   - Messages are sent to the LLM
   - Token counting occurs (`TokenCounted` event)
   - Context pruning may occur (`ContextPruned` event)
   - Response is received (`RequestCompleted` event)
   - If the response contains tool calls:
     - Each tool is executed (`PreToolCall` and `PostToolCall` events)
     - Tool results are added to the conversation
     - Loop continues with next LLM request
   - If no tool calls, conversation ends
6. **Conversation End** - `PostConversation` event is emitted

## Event System

The agent emits events throughout its lifecycle, allowing you to monitor, log,
and react to agent behavior. Events are processed asynchronously through an
internal event queue.

### Adding Event Listeners

Event listeners are async functions that receive events. You can add multiple
listeners to track different aspects of agent behavior:

```moonbit
///|
async test "track-conversation" {
  let agent = @agent.new(model, cwd=@os.cwd())
  agent.add_listener(event => match event {
    PreConversation => println("Conversation starting...")
    PostConversation => println("Conversation complete!")
    _ => ()
  })
}

///|
async test "track-tool-calls" {
  let agent = @agent.new(model, cwd=@os.cwd())
  let tool_calls = Ref::new([])
  agent.add_listener(event => match event {
    PreToolCall(tool_call) => {
      println("Calling tool: \{tool_call.function.name}")
      tool_calls.val.push(tool_call.function.name)
    }
    PostToolCall(tool_call, result~, ..) =>
      match result {
        Ok(_) => println("Tool \{tool_call.function.name} succeeded")
        Err(error) =>
          println("Tool \{tool_call.function.name} failed: \{error}")
      }
    _ => ()
  })
}

///|
async test "track-token-pruning" {
  let agent = @agent.new(model, cwd=@os.cwd())
  agent.add_listener(event => match event {
    TokenCounted(count) => println("Tokens before pruning: \{count}")
    ContextPruned(origin_token_count~, pruned_token_count~) => {
      let saved = origin_token_count - pruned_token_count
      println("Pruned \{saved} tokens")
    }
    _ => ()
  })
}
```

### Event Processing

Events are emitted synchronously but processed asynchronously:

1. When an event occurs, it's added to an internal event queue
2. A background task processes events from the queue
3. All registered listeners receive each event in order
4. Events are also automatically logged in structured JSON format

This design ensures:

- Events never block the main agent logic
- All listeners receive events in a consistent order
- Event processing doesn't interfere with conversation flow

## Sample Event Trajectory

Here's a typical event sequence for a simple agent interaction:

```text
User: "Use the add_numbers tool to calculate 5 + 3"

Event Flow:
┌─────────────────────────────────────────────────────────────┐
│ 1. MessageAdded                                             │
│    - User message added to queue                            │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. PreConversation                                          │
│    - Agent starts processing                                │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. TokenCounted(1247)                                       │
│    - Initial token count before pruning                     │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. ContextPruned                                            │
│    - origin_token_count: 1247                               │
│    - pruned_token_count: 1247                               │
│    - (No pruning needed, under token limit)                 │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. RequestCompleted                                         │
│    - LLM responds with tool call request                    │
│    - usage: {prompt_tokens: 1247, completion_tokens: 45}    │
│    - message.tool_calls: [add_numbers]                      │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. PreToolCall                                              │
│    - tool_call.function.name: "add_numbers"                 │
│    - tool_call.function.arguments: '{"a": 5, "b": 3}'       │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. PostToolCall                                             │
│    - result: Ok({"result": 8})                              │
│    - rendered: 'Result: 8'                                  │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. MessageAdded                                             │
│    - Tool result message added to history                   │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 9. TokenCounted(1356)                                       │
│    - Token count including tool result                      │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 10. ContextPruned                                           │
│     - origin_token_count: 1356                              │
│     - pruned_token_count: 1356                              │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 11. RequestCompleted                                        │
│     - LLM responds with final answer                        │
│     - usage: {prompt_tokens: 1356, completion_tokens: 12}   │
│     - message.content: "The result is 8."                   │
│     - message.tool_calls: [] (no more tool calls)           │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ 12. PostConversation                                        │
│     - Conversation complete                                 │
└─────────────────────────────────────────────────────────────┘
```

## Advanced Features

### Context Pruning

The agent automatically manages conversation context to stay within token limits:

- **Token Counting**: Before each request, tokens are counted
- **Automatic Pruning**: If tokens exceed the safe zone, older messages are removed
- **Event Notification**: `ContextPruned` events show original and pruned token counts

### Conversation History

The agent maintains conversation history automatically:

- All user, assistant, and tool messages are tracked
- History is persisted to disk via the session manager
- Conversations can be resumed across agent restarts

### Logging

All events are automatically logged in structured JSON format:

```json
{
  "level": "info",
  "msg": "PreToolCall",
  "tool_call": {
    "id": "call_abc123",
    "function": {
      "name": "add_numbers",
      "arguments": "{\"a\": 5, \"b\": 3}"
    }
  },
  "name": "add_numbers",
  "args": {"a": 5, "b": 3}
}
```

Logs are written to `.moonagent/log` by default, but can be customized:

```moonbit
///|
async test "custom-logging" {
  let custom_logger = @pino.logger(
    "my_agent",
    @pino.transport("file:custom_log_path"),
  )
  let agent = @agent.new(model, cwd=@os.cwd(), logger=custom_logger)
  agent.add_message(@openai.user_message(content="Hello, custom logger!"))
  agent.start()
}
```

## Best Practices

1. **Event Listeners**: Add event listeners before starting the conversation to capture all events

2. **Tool Design**: Keep tools focused and well-documented with clear schemas

3. **Error Handling**: Use `PostToolCall` events to monitor tool failures and handle errors gracefully

4. **Token Management**: Monitor `ContextPruned` events to understand when context is being trimmed

5. **Logging**: Use the default logging to debug agent behavior in production

6. **Async Handling**: Remember that event listeners are async - use `Ref` for mutable state

## See Also

- `@tool` package - Tool creation and execution
- `@model` package - LLM model configuration
- `@openai` package - OpenAI API integration
