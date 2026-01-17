///|
const OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"

///|
fn deepseek_model(api_key : String) -> @model.Model {
  @model.new(
    api_key~,
    base_url=OPENROUTER_BASE_URL,
    name="deepseek/deepseek-v3.2-exp",
    safe_zone_tokens=100000,
  )
}

///|
fn claude_haiku_model(api_key : String) -> @model.Model {
  @model.new(
    api_key~,
    base_url="https://openrouter.ai/api/v1",
    name="anthropic/claude-haiku-4.5",
    safe_zone_tokens=200000,
  )
}

///|
fn claude_sonnet_model(api_key : String) -> @model.Model {
  @model.new(
    api_key~,
    base_url="https://openrouter.ai/api/v1",
    name="anthropic/claude-sonnet-4.5",
    safe_zone_tokens=200000,
  )
}

///|
/// Test basic text completion
async test "text" {
  guard @os.getenv("OPENAI_API_KEY") is Some(api_key) else {
    fail("OPENAI_API_KEY not set")
  }
  let model = deepseek_model(api_key)
  let response = text(model~, prompt="Say 'Hello, World!' and nothing else.")
  inspect(response.contains("Hello"), content="true")
}

///|
/// Test JSON response parsing
async test "json" {
  guard @os.getenv("OPENAI_API_KEY") is Some(api_key) else {
    fail("OPENAI_API_KEY not set")
  }
  let model = deepseek_model(api_key)
  let response = json(
    model~,
    prompt="Return a JSON object with a 'message' field containing 'Hello, World!'. Wrap it in ```json```.",
  )
  guard response is { "message": String(message), .. } &&
    message.contains("Hello") else {
    fail("Expected JSON object")
  }
}

///|
/// Test basic chat completion
async test "chat" {
  guard @os.getenv("OPENAI_API_KEY") is Some(api_key) else {
    fail("OPENAI_API_KEY not set")
  }
  let model = deepseek_model(api_key)
  let completion = chat(
    model~,
    chat_completion(
      model=model.model_name,
      messages=[
        system_message(content="You are a helpful assistant."),
        user_message(content="Say 'Hello' and nothing else."),
      ],
      max_tokens=50,
      temperature=0.7,
    ),
  )
  guard completion.choices
    is [{ message: { content: Some(content), .. }, .. }, ..] &&
    content.contains("Hello") else {
    fail("Expected choices with message content")
  }
}

///|
/// Test chat completion with usage tracking
async test "chat_with_usage" {
  guard @os.getenv("OPENAI_API_KEY") is Some(api_key) else {
    fail("OPENAI_API_KEY not set")
  }
  let model = deepseek_model(api_key)
  let completion = chat(
    model~,
    chat_completion(
      model=model.model_name,
      messages=[
        system_message(content="You are a helpful assistant."),
        user_message(content="Say 'Hello' and nothing else."),
      ],
      max_tokens=50,
      temperature=0.7,
      usage=usage(include_=true),
    ),
  )
  guard completion.usage is Some(usage) else { fail("Expected usage data") }
  assert_true(usage.total_tokens > 0)
  assert_true(usage.prompt_tokens > 0)
  assert_true(usage.completion_tokens > 0)
}

///|
/// Test tool definition
test "tool_definition" {
  let tool_def = @openai.tool(
    name="get_weather",
    description="Get the current weather in a location",
    parameters={
      "type": "object",
      "properties": { "location": { "type": "string" } },
      "required": ["location"],
    },
  )
  let json = tool_def.to_json()
  guard json is { "type": "function", "function": _, .. } else {
    fail("Expected JSON object")
  }
}

///|
/// Test response format helpers
test "response_format" {
  let text_format = ResponseFormat::Text
  let json = text_format.to_json()
  guard json is Object(obj) else { fail("Expected JSON object") }
  guard obj.get("type") is Some(String("text")) else {
    fail("Expected type 'text'")
  }
  let json_schema_format = json_schema(name="test_schema", schema={
    "type": "object",
    "properties": { "message": { "type": "string" } },
  })
  let json = json_schema_format.to_json()
  guard json is { "type": "json_schema", .. } else {
    fail("Expected JSON object")
  }
}

///|
async test "streaming" (t : @test.Test) {
  @mock.run(t, mock => {
    let api_key = mock.getenv("OPENAI_API_KEY")
    let model = deepseek_model(api_key)
    let chat_completion = @openai.chat(
      model~,
      chat_completion(
        model=model.model_name,
        messages=[
          system_message(content="You are a helpful assistant."),
          user_message(content="Stream a response saying 'Hello, World!'"),
        ],
        max_tokens=50,
        temperature=0.7,
        stream=true,
      ),
    )
    @json.inspect(
      chat_completion.choices[0].message.content
      .unwrap()
      .contains("Hello, World!"),
      content=true,
    )
  })
}

///|
async test "streaming_tool_call" (t : @test.Test) {
  @mock.run(t, mock => {
    let api_key = mock.getenv("OPENAI_API_KEY")
    let model = claude_haiku_model(api_key)
    let chat_completion = @openai.chat(
      model~,
      chat_completion(
        model=model.model_name,
        messages=[
          system_message(content="You are a helpful assistant."),
          user_message(
            content="Call the tool 'get_weather' with location 'San Francisco'.",
          ),
        ],
        tools=[
          @openai.tool(
            name="get_weather",
            description="Get the current weather in a location",
            parameters={
              "type": "object",
              "properties": { "location": { "type": "string" } },
              "required": ["location"],
            },
          ),
        ],
        max_tokens=100,
        temperature=0.7,
        stream=true,
      ),
    )
    @json.inspect(
      chat_completion.choices[0].message.tool_calls[0].function.name,
      content="get_weather",
    )
    @json.inspect(
      @json.parse(
        chat_completion.choices[0].message.tool_calls[0].function.arguments.unwrap(),
      ),
      content={ "location": "San Francisco" },
    )
  })
}

///|
async test "streaming_parallel_tool_call" (t : @test.Test) {
  @mock.run(t, mock => {
    let api_key = mock.getenv("OPENAI_API_KEY")
    let model = claude_sonnet_model(api_key)
    let chat_completion = @openai.chat(
      model~,
      chat_completion(
        model=model.model_name,
        messages=[
          system_message(content="You are a helpful assistant."),
          user_message(
            content="Call the tool 'get_weather' twice in parallel with location 'San Francisco' and 'Boston' respectively.",
          ),
        ],
        tools=[
          @openai.tool(
            name="get_weather",
            description="Get the current weather in a location",
            parameters={
              "type": "object",
              "properties": { "location": { "type": "string" } },
              "required": ["location"],
            },
          ),
        ],
        max_tokens=100,
        temperature=0.7,
        stream=true,
      ),
    )
    let tool_calls : Array[@openai.ChatCompletionMessageToolCall] = chat_completion.choices[0].message.tool_calls
    let tool_calls = tool_calls.map(tc => {
      guard tc.to_json() is Object(tc_object)
      tc_object.remove("id")
      if tc.function.arguments is Some(arguments) {
        tc_object["function"].as_object().unwrap()["arguments"] = @json.parse(
          arguments,
        )
      }
      tc_object.to_json()
    })
    tool_calls.sort_by((a, b) => a.stringify().compare(b.stringify()))
    @json.inspect(tool_calls, content=[
      {
        "function": {
          "name": "get_weather",
          "arguments": { "location": "Boston" },
        },
        "type": "function",
      },
      {
        "function": {
          "name": "get_weather",
          "arguments": { "location": "San Francisco" },
        },
        "type": "function",
      },
    ])
  })
}
