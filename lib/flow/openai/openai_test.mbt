///|
test "system_message" {
  @json.inspect(
    @openai.system_message(content="You are a helpful assistant."),
    content={ "role": "system", "content": "You are a helpful assistant." },
  )
}

///|
test "user_message" {
  @json.inspect(@openai.user_message(content="Hello", name="Alice"), content={
    "role": "user",
    "content": "Hello",
    "name": "Alice",
  })
}

///|
test "assistant_message" {
  @json.inspect(@openai.assistant_message(content="Hi there!"), content={
    "role": "assistant",
    "tool_calls": [],
    "content": "Hi there!",
  })
}

///|
test "ChatCompletionChoice" {
  let json : Json = {
    "id": "gen-1761639397-aseLxfjMsPT5jVOhxXdW",
    "provider": "Novita",
    "model": "qwen/qwen3-coder",
    "object": "chat.completion",
    "created": 1761639398,
    "choices": [
      {
        "logprobs": null,
        "finish_reason": "tool_calls",
        "native_finish_reason": "tool_calls",
        "index": 0,
        "message": {
          "role": "assistant",
          "content": "Now let's create a new MoonBit project for our JSON parser:\n\n",
          "refusal": null,
          "reasoning": null,
          "tool_calls": [
            {
              "index": 0,
              "id": "call_6abfac48947b4400afbf1d5c",
              "type": "function",
              "function": {
                "name": "execute_command",
                "arguments": "{\"command\": \"moon new json_parser\", \"timeout\": 10000}",
              },
            },
          ],
        },
      },
    ],
    "system_fingerprint": "",
    "usage": {
      "prompt_tokens": 17744,
      "completion_tokens": 53,
      "total_tokens": 17797,
      "prompt_tokens_details": null,
      "completion_tokens_details": null,
    },
  }
  let completion : @openai.ChatCompletion = @json.from_json(json)
  @json.inspect(completion, content={
    "id": "gen-1761639397-aseLxfjMsPT5jVOhxXdW",
    "choices": [
      {
        "index": 0,
        "message": {
          "content": "Now let's create a new MoonBit project for our JSON parser:\n\n",
          "role": "assistant",
          "tool_calls": [
            {
              "id": "call_6abfac48947b4400afbf1d5c",
              "function": {
                "name": "execute_command",
                "arguments": "{\"command\": \"moon new json_parser\", \"timeout\": 10000}",
              },
              "type": "function",
            },
          ],
        },
        "finish_reason": "tool_calls",
      },
    ],
    "created": 1761639398,
    "model": "qwen/qwen3-coder",
    "usage": {
      "completion_tokens": 53,
      "prompt_tokens": 17744,
      "total_tokens": 17797,
    },
    "system_fingerprint": "",
  })
  let json : Json = {
    "id": "gen-1761643890-jGqb3sMZR2Kc7xT50AXU",
    "provider": "SiliconFlow",
    "model": "z-ai/glm-4.6",
    "object": "chat.completion",
    "created": 1761643890,
    "choices": [
      {
        "error": {
          "message": "Error processing stream",
          "code": 502,
          "metadata": {
            "provider_name": "SiliconFlow",
            "raw": { "retryable": true },
          },
        },
        "logprobs": null,
        "finish_reason": null,
        "native_finish_reason": null,
        "index": 0,
        "message": {
          "role": "assistant",
          "content": "\n",
          "refusal": null,
          "reasoning": null,
        },
      },
    ],
    "system_fingerprint": "",
    "usage": {
      "prompt_tokens": 27397,
      "completion_tokens": 1,
      "total_tokens": 27398,
    },
  }
  let completion : @openai.ChatCompletion = @json.from_json(json)
  @json.inspect(completion, content={
    "id": "gen-1761643890-jGqb3sMZR2Kc7xT50AXU",
    "choices": [
      {
        "index": 0,
        "message": { "content": "\n", "role": "assistant", "tool_calls": [] },
      },
    ],
    "created": 1761643890,
    "model": "z-ai/glm-4.6",
    "usage": {
      "completion_tokens": 1,
      "prompt_tokens": 27397,
      "total_tokens": 27398,
    },
    "system_fingerprint": "",
  })
}

///|
test "tool_call" {
  let tool_call = @openai.tool_call(
    id="call_6abfac48947b4400afbf1d5c",
    name="execute_command",
    arguments="{\"command\": \"moon new json_parser\", \"timeout\": 10000}",
  )
  @json.inspect(tool_call, content={
    "id": "call_6abfac48947b4400afbf1d5c",
    "function": {
      "name": "execute_command",
      "arguments": "{\"command\": \"moon new json_parser\", \"timeout\": 10000}",
    },
    "type": "function",
  })
}
