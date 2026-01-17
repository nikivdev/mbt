///|
async test "replace_in_file/create" (t : @test.Test) {
  @mock.run(t, taco => {
    let manager = @file.manager(cwd=taco.cwd.path())
    let args : Json = { "path": "nonexistent.txt" }
    let result = @replace_in_file.new(manager).call(args)
    @json.inspect(result, content=[
      "Error",
      ["JsonDecodeError", ["", "Missing field replace"]],
      "Error: Invalid arguments provided to replace_in_file tool: JsonDecodeError((, \"Missing field replace\"))",
    ])
  })
}

///|
async test "replace_in_file/replace" (t : @test.Test) {
  @mock.run(t, taco => {
    let manager = @file.manager(cwd=taco.cwd.path())
    let _ = taco.add_file("file.txt", content="Old content")
    @json.inspect(@read_file.new(manager).call({ "path": "file.txt" }), content=[
      "Ok",
      {
        "path": "file.txt",
        "content": "Old content",
        "start_line": 1,
        "end_line": 1,
      },
    ])
    let args : Json = {
      "path": "file.txt",
      "search": "Old content",
      "replace": "New content",
    }
    let result = @replace_in_file.new(manager).call(args)
    @json.inspect(result, content=[
      "Ok",
      {
        "path": "file.txt",
        "operation": "Updated",
        "bytes_written": 11,
        "search_used": true,
        "message": "Changes applied to file.txt",
        "content": "New content",
      },
    ])
  })
}

///|
async test "replace_in_file/fail-to-match" (t : @test.Test) {
  @mock.run(t, taco => {
    let manager = @file.manager(cwd=taco.cwd.path())
    let _ = taco.add_file("file.txt", content="Old content")
    let args : Json = {
      "path": "file.txt",
      "search": "Non-matching content",
      "replace": "New content",
    }
    let result = @replace_in_file.new(manager).call(args)
    @json.inspect(result, content=[
      "Error",
      [
        "ToolFailure", "Search content not found in file (tried all matching strategies): Non-matching content",
      ],
      "Search content not found in file (tried all matching strategies): Non-matching content",
    ])
  })
}

///|
async test "replace_in_file/search-replace" (t : @test.Test) {
  @mock.run(t, taco => {
    let manager = @file.manager(cwd=taco.cwd.path())
    let _ = taco.add_file(
      "file.txt",
      content=(
        #|line 1
        #|line 2
        #|line 3
        #|line 4
      ),
    )
    let args : Json = {
      "path": "file.txt",
      "search": "line 2",
      "replace": "line 2 modified",
    }
    let result = @replace_in_file.new(manager).call(args)
    @json.inspect(result, content=[
      "Ok",
      {
        "path": "file.txt",
        "operation": "Updated",
        "bytes_written": 36,
        "search_used": true,
        "message": "Changes applied to file.txt",
        "content": "line 1\nline 2 modified\nline 3\nline 4",
      },
    ])
  })
}

///|
async test "replace_in_file/agentic" (t : @test.Test) {
  // TODO: add retries support
  @mock.run(timeout=60_000, retry=3, t, taco => {
    let api_key = taco.getenv("OPENAI_API_KEY")
    let manager = @file.manager(cwd=taco.cwd.path())
    let file = taco.add_file(
      "file.txt",
      content=(
        #|line 1
        #|line 2
        #|line 3
        #|line 4
      ),
    )
    let model = @model.new(
      api_key~,
      base_url="https://openrouter.ai/api/v1",
      name="qwen/qwen3-coder-plus",
      safe_zone_tokens=200000,
    )
    let agent = @agent.new(model, cwd=taco.cwd.path())
    agent.add_listener(event => match event {
      PostToolCall(tool_call, result~, rendered~) =>
        taco.logger.info("PostToolCall", {
          "name": tool_call.function.name.to_json(),
          "output": result.to_json(),
          "text": rendered.to_json(),
        })
      _ => ()
    })
    agent.add_tool(@replace_in_file.new(manager))
    agent.add_message(
      @openai.user_message(
        content="Update line 2 in file.txt to say 'line 2 modified via agent'.",
      ),
    )
    agent.start()
    inspect(
      file.read(),
      content=(
        #|line 1
        #|line 2 modified via agent
        #|line 3
        #|line 4
      ),
    )
  })
}

///|
/// does not make sense to test render separately as it's just returning the error message
// async test "replace_in_file/render" {
//   @json.inspect(
//     (@replace_in_file.new("").render)(@tool.error("Some error occurred")),
//     content="Some error occurred",
//   )
// }
