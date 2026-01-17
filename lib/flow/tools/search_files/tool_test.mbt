///|
async test "search_files" (t : @test.Test) {
  @mock.run(t, taco => {
    let _ = taco.add_file(
      "notes.txt",
      content=(
        #|These are some notes about the project.
        #|We need to implement a feature to search files.
        #|The search should be efficient and accurate.
      ),
    )
    let args : Json = { "path": ".", "regex": "search files", "kind": "regex" }
    let result = @search_files.new(taco.cwd.path()).call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(output, content=[
      "SearchResultData",
      {
        "kind": "Regex",
        "query": "search files",
        "path": ".",
        "file_pattern": "*",
        "context_lines": 2,
        "total_matches": 1,
        "results": [
          {
            "context": "1: These are some notes about the project.\n2: We need to implement a feature to search files.\n3: The search should be efficient and accurate.",
            "line_number": 2,
            "match_line": "We need to implement a feature to search files.",
            "path": "notes.txt",
          },
        ],
        "truncated": false,
        "message": "Search completed. Found 1 matches. Note: gitignore rules were not fully respected during the search as \"git check-ignore\" fails to execute properly.",
      },
    ])
  })
}

///|
async test "search_files-moon-definition" (t : @test.Test) {
  @mock.run(t, mock => {
    mock.add_files([
      (
        "moon.mod.json",
        { "name": "username/example", "version": "0.1.0" }
        .to_json()
        .stringify(indent=2),
      ),
      ("moon.pkg.json", Json::object({}).stringify(indent=2)),
      (
        "main.mbt",
        (
          #|///|
          #|pub fn greet(name : String) -> String {
          #|  println("Hello, \{name}!")
          #|}
        ),
      ),
    ])
    let args : Json = {
      "path": ".",
      "regex": "@username/example greet",
      "kind": "moonbit_definition",
    }
    let result = @search_files.new(mock.cwd.path()).call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(mock.json(output), content=[
      "MoonbitToolResult",
      {
        "kind": "MoonbitDefinition",
        "query": "@username/example greet",
        "path": ".",
        "working_directory": "(mock:cwd)",
        "output": "Search completed using fuzzy symbolic search for MoonBit definitions.\nNote: The search pattern \"@username/example greet\" was used for fuzzy matching of symbol names.\n\nThere are total 1 symbols match query '@username/example greet':\nTop 1 best-matching symbols:\n\n`pub fn greet` in package username/example at (mock:cwd)/main.mbt:1-4:\n        ^^^^^             ^^^^^^^^^^^^^^^^\n1 | ///|\n  | pub fn greet(name : String) -> String {\n  |   println(\"Hello, \\{name}!\")\n  | }\n\n",
        "message": "Search completed using fuzzy symbolic search for MoonBit definitions.",
      },
    ])
  })
}

///|
async test "search_files-moon-references" (t : @test.Test) {
  @mock.run(t, mock => {
    mock.add_files([
      (
        "moon.mod.json",
        { "name": "username/example", "version": "0.1.0" }
        .to_json()
        .stringify(indent=2),
      ),
      ("moon.pkg.json", Json::object({}).stringify(indent=2)),
      (
        "main.mbt",
        (
          #|///|
          #|pub fn greet(name : String) -> String {
          #|  println("Hello, \{name}!")
          #|}
          #|
          #|fn main {
          #|  greet("World")
          #|  greet("MoonBit")
          #|}
        ),
      ),
    ])
    let args : Json = {
      "path": ".",
      "regex": "@username/example greet",
      "kind": "moonbit_references",
    }
    let result = @search_files.new(mock.cwd.path()).call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(mock.json(output), content=[
      "MoonbitToolResult",
      {
        "kind": "MoonbitReferences",
        "query": "@username/example greet",
        "path": ".",
        "working_directory": "(mock:cwd)",
        "output": "Search completed using MoonBit IDE find-references tool.\nQuery: \"@username/example greet\"\nWorking directory: (mock:cwd)\n\n`pub fn greet` in package username/example at (mock:cwd)/main.mbt:1-4:\n        ^^^^^             ^^^^^^^^^^^^^^^^\n1 | ///|\n  | pub fn greet(name : String) -> String {\n  |   println(\"Hello, \\{name}!\")\n  | }\n\nFound 5 references of this symbol:\n(mock:cwd)/main.mbt:2:8-2:13:\n  | ///|\n2 | pub fn greet(name : String) -> String {\n  |        ^^^^^\n  |   println(\"Hello, \\{name}!\")\n  | }\n\n(mock:cwd)/main.mbt:7:3-7:8:\n  | }\n  | \n  | fn main {\n7 |   greet(\"World\")\n  |   ^^^^^\n  |   greet(\"MoonBit\")\n  | }\n\n(mock:cwd)/main.mbt:8:3-8:8:\n  | \n  | fn main {\n  |   greet(\"World\")\n8 |   greet(\"MoonBit\")\n  |   ^^^^^\n  | }\n\n(mock:cwd)/main.mbt:7:3-7:8:\n  | }\n  | \n  | fn main {\n7 |   greet(\"World\")\n  |   ^^^^^\n  |   greet(\"MoonBit\")\n  | }\n\n(mock:cwd)/main.mbt:8:3-8:8:\n  | \n  | fn main {\n  |   greet(\"World\")\n8 |   greet(\"MoonBit\")\n  |   ^^^^^\n  | }\n\n",
        "message": "Search completed using MoonBit IDE find-references tool.",
      },
    ])
  })
}

///|
async test "search_files/agentic" (t : @test.Test) {
  @mock.run(t, timeout=300_000, taco => {
    let api_key = taco.getenv("OPENAI_API_KEY")
    taco.add_files([
      (
        "notes.txt",
        (
          #|These are some notes about the project.
          #|We need to implement a feature to search files.
          #|The search should be efficient and accurate.
        ),
      ),
      (
        "file.txt",
        (
          #|This file contains some important information.
          #|Make sure to read it carefully.
        ),
      ),
    ])
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
          "tool_call": tool_call.to_json(),
          "tool_call_result": result.to_json(),
          "tool_call_result_text": rendered.to_json(),
        })
      _ => ()
    })
    let file_manager = @file.manager(cwd=taco.cwd.path())
    agent.add_tools([
      @replace_in_file.new(file_manager).to_agent_tool(),
      @search_files.new(taco.cwd.path()).to_agent_tool(),
    ])
    agent.add_message(
      @openai.user_message(
        content=(
          $|You are an AI assistant that helps users search for text in files.
          $|The user wants to find the phrase "search files" in the project files.
          $|Use the `search_files` tool to perform the search and provide the results by writing to `results.txt`.
        ),
      ),
    )
    agent.start()
    inspect(
      @fsx.read_file(@path.join(taco.cwd.path(), "results.txt")).contains(
        "notes.txt",
      ),
      content="true",
    )
  })
}

///|
async test "search_files/with tilde expension" (t : @test.Test) {
  @mock.run(t, taco => {
    let args : Json = {
      "path": "~/.moon/lib/core",
      "regex": "parse.*Double",
      "kind": "regex",
      "file_pattern": "*.mbti",
    }
    let result = @search_files.new(taco.cwd.path()).call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    let result = output.to_string()
    assert_true(result.contains("parse_decimal"))
    assert_true(result.contains("parse_double"))
    assert_true(result.contains("parse_int"))
  })
}

///|
async test "search_files/gitignore" (t : @test.Test) {
  @mock.run(t, mock => {
    @git.init_(mock.cwd.path())
    mock.add_files([
      (
        ".gitignore",
        (
          #|ignored.txt
        ),
      ),
      (
        "ignored.txt",
        (
          #|This file should be ignored by git.
        ),
      ),
      (
        "not_ignored.txt",
        (
          #|This file should not be ignored by git.
        ),
      ),
    ])
    let args : Json = { "path": ".", "regex": "file", "kind": "regex" }
    let result = @search_files.new(mock.cwd.path()).call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    let result = output.to_string()
    inspect(
      result,
      content=(
        #|Search completed. Found 1 matches. Note: gitignore rules were not fully respected during the search as "git check-ignore" fails to execute properly.
        #|
        #|not_ignored.txt:1
        #|1: This file should not be ignored by git.
        #|
      ),
    )
  })
}

///|
async test "search_files/gitignore-without-git" (t : @test.Test) {
  @mock.run(t, mock => {
    mock.add_files([
      (
        ".gitignore",
        (
          #|ignored.txt
        ),
      ),
      (
        "ignored.txt",
        (
          #|This file should be ignored by git.
        ),
      ),
      (
        "not_ignored.txt",
        (
          #|This file should not be ignored by git.
        ),
      ),
    ])
    let args : Json = { "path": ".", "regex": "file", "kind": "regex" }
    let tool = @search_files.new(mock.cwd.path())
    let result = tool.call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    let result = output.to_string()
    inspect(
      result,
      content=(
        #|Search completed. Found 2 matches. Note: gitignore rules were not fully respected during the search as "git check-ignore" fails to execute properly.
        #|
        #|ignored.txt:1
        #|1: This file should be ignored by git.
        #|
        #|not_ignored.txt:1
        #|1: This file should not be ignored by git.
        #|
      ),
    )
  })
}

///|
async test "search_files/does-not-respect-gitignore" (t : @test.Test) {
  @mock.run(t, mock => {
    @git.init_(mock.cwd.path())
    mock.add_files([
      (
        ".gitignore",
        (
          #|ignored.txt
        ),
      ),
      (
        "ignored.txt",
        (
          #|This file should be ignored by git.
        ),
      ),
      (
        "not_ignored.txt",
        (
          #|This file should not be ignored by git.
        ),
      ),
    ])
    let args : Json = {
      "path": ".",
      "regex": "ignored",
      "kind": "regex",
      "respect_gitignore": false,
    }
    let result = @search_files.new(mock.cwd.path()).call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    let result = output.to_string()
    inspect(
      result,
      content=(
        #|Search completed. Found 3 matches.
        #|
        #|.gitignore:1
        #|1: ignored.txt
        #|
        #|ignored.txt:1
        #|1: This file should be ignored by git.
        #|
        #|not_ignored.txt:1
        #|1: This file should not be ignored by git.
        #|
      ),
    )
  })
}
