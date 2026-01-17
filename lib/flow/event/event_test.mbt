///|
fn redact_events(events : Array[@event.Event]) -> Array[Json] {
  events.map(event => event
    .to_json()
    .transform(
      @json.Replacer::exclude(["level", "pid", "hostname", "time", "tag"]),
    ))
}

///|
async test "Event::ToJson/PreConversation" {
  let events = []
  @async.with_task_group(group => {
    let emitter = @event.EventTarget::new()
    group.spawn_bg(() => emitter.start(), no_wait=true)
    emitter.add_listener(event => events.push(event))
    emitter.emit(PreConversation)
  })
  @json.inspect(redact_events(events), content=[{ "msg": "PreConversation" }])
}

///|
async test "Event::ToJson/PostConversation" {
  let events = []
  @async.with_task_group(group => {
    let emitter = @event.EventTarget::new()
    group.spawn_bg(() => emitter.start(), no_wait=true)
    emitter.add_listener(event => events.push(event))
    emitter.emit(PostConversation)
  })
  @json.inspect(redact_events(events), content=[{ "msg": "PostConversation" }])
}

///|
async test "Event::ToJson/TokenCounted" {
  let events = []
  @async.with_task_group(group => {
    let emitter = @event.EventTarget::new()
    group.spawn_bg(() => emitter.start(), no_wait=true)
    emitter.add_listener(event => events.push(event))
    emitter.emit(TokenCounted(42))
  })
  @json.inspect(redact_events(events), content=[
    { "msg": "TokenCounted", "token_count": 42 },
  ])
}

///|
async test "Event::ToJson/ContextPruned" {
  let events = []
  @async.with_task_group(group => {
    let emitter = @event.EventTarget::new()
    group.spawn_bg(() => emitter.start(), no_wait=true)
    emitter.add_listener(event => events.push(event))
    emitter.emit(ContextPruned(origin_token_count=100, pruned_token_count=20))
  })
  @json.inspect(redact_events(events), content=[
    {
      "msg": "ContextPruned",
      "origin_token_count": 100,
      "pruned_token_count": 20,
    },
  ])
}

///|
async test "Event::ToJson/PreToolCall" {
  let events = []
  @async.with_task_group(group => {
    let emitter = @event.EventTarget::new()
    group.spawn_bg(() => emitter.start(), no_wait=true)
    emitter.add_listener(event => events.push(event))
    emitter.emit(
      PreToolCall(
        @openai.tool_call(
          id="tool_call_1",
          name="example_tool",
          arguments="{\"param1\": \"value1\", \"param2\": 123}",
        ),
      ),
    )
  })
  @json.inspect(redact_events(events), content=[
    {
      "msg": "PreToolCall",
      "tool_call": {
        "id": "tool_call_1",
        "function": {
          "name": "example_tool",
          "arguments": "{\"param1\": \"value1\", \"param2\": 123}",
        },
        "type": "function",
      },
      "name": "example_tool",
      "args": { "param1": "value1", "param2": 123 },
    },
  ])
}

///|
async test "Event::ToJson/PostToolCall success" {
  let events = []
  @async.with_task_group(group => {
    let emitter = @event.EventTarget::new()
    group.spawn_bg(() => emitter.start(), no_wait=true)
    emitter.add_listener(event => events.push(event))
    emitter.emit(
      PostToolCall(
        @openai.tool_call(
          id="tool_call_1",
          name="example_tool",
          arguments="{\"param1\": \"value1\", \"param2\": 123}",
        ),
        result=Ok("Tool call result"),
        rendered="Tool call rendered output",
      ),
    )
  })
  @json.inspect(redact_events(events), content=[
    {
      "msg": "PostToolCall",
      "tool_call": {
        "id": "tool_call_1",
        "function": {
          "name": "example_tool",
          "arguments": "{\"param1\": \"value1\", \"param2\": 123}",
        },
        "type": "function",
      },
      "name": "example_tool",
      "result": "Tool call result",
      "text": "Tool call rendered output",
    },
  ])
}

///|
async test "Event::ToJson/PostToolCall error" {
  let events = []
  @async.with_task_group(group => {
    let emitter = @event.EventTarget::new()
    group.spawn_bg(() => emitter.start(), no_wait=true)
    emitter.add_listener(event => events.push(event))
    emitter.emit(
      PostToolCall(
        @openai.tool_call(
          id="tool_call_2",
          name="failing_tool",
          arguments="{\"paramA\": \"valueA\"}",
        ),
        result=Err(Failure("Tool call error")),
        rendered="Tool call error output",
      ),
    )
  })
  @json.inspect(redact_events(events), content=[
    {
      "msg": "PostToolCall",
      "tool_call": {
        "id": "tool_call_2",
        "function": {
          "name": "failing_tool",
          "arguments": "{\"paramA\": \"valueA\"}",
        },
        "type": "function",
      },
      "name": "failing_tool",
      "error": ["Failure", "Tool call error"],
      "text": "Tool call error output",
    },
  ])
}

///|
async test "Event::ToJson/MessageAdded" {
  let events = []
  @async.with_task_group(group => {
    let emitter = @event.EventTarget::new()
    group.spawn_bg(() => emitter.start(), no_wait=true)
    emitter.add_listener(event => events.push(event))
    emitter.emit(
      MessageAdded(
        @openai.user_message(content="Hello, this is a user message."),
      ),
    )
  })
  @json.inspect(redact_events(events), content=[
    {
      "msg": "MessageAdded",
      "message": { "role": "user", "content": "Hello, this is a user message." },
    },
  ])
}

///|
async test "Event::ToJson/ToolAdded" {
  let events = []
  @async.with_task_group(group => {
    let emitter = @event.EventTarget::new()
    group.spawn_bg(() => emitter.start(), no_wait=true)
    emitter.add_listener(event => events.push(event))
    let tool = @tool.new(
      description="A sample tool for demonstration.",
      name="sample_tool",
      schema="{\"type\": \"object\", \"properties\": {\"param\": {\"type\": \"string\"}}}",
      _ => @tool.ToolResult::ok("Sample output"),
    )
    emitter.emit(ToolAdded(tool.desc))
  })
  @json.inspect(redact_events(events), content=[
    {
      "msg": "ToolAdded",
      "tool": {
        "name": "sample_tool",
        "description": "A sample tool for demonstration.",
        "schema": "{\"type\": \"object\", \"properties\": {\"param\": {\"type\": \"string\"}}}",
      },
    },
  ])
}

///|
async test "Event::ToJson/RequestCompleted" {
  let events = []
  @async.with_task_group(group => {
    let emitter = @event.EventTarget::new()
    emitter.add_listener(event => events.push(event))
    group.spawn_bg(() => emitter.start(), no_wait=true)
    let usage : Json = {
      "completion_tokens": 50,
      "prompt_tokens": 150,
      "total_tokens": 200,
    }
    let usage : @openai.CompletionUsage = @json.from_json(usage)
    let message : Json = {
      "content": "This is the final message from the model.",
      "role": "assistant",
      "tool_calls": [],
    }
    let message : @openai.ChatCompletionMessage = @json.from_json(message)
    emitter.emit(RequestCompleted(usage=Some(usage), message~))
  })
  @json.inspect(redact_events(events), content=[
    {
      "msg": "RequestCompleted",
      "usage": [
        { "completion_tokens": 50, "prompt_tokens": 150, "total_tokens": 200 },
      ],
      "message": {
        "content": "This is the final message from the model.",
        "role": "assistant",
        "tool_calls": [],
      },
    },
  ])
}
