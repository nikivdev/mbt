///|
#skip
async test "fix-syntax-error" (t : @test.Test) {
  @mock.run(t, retry=3, mock => {
    let model = mock.model()
    mock.add_files([
      (
        "moon.mod.json",
        Json::object({ "name": "example", "version": "0.1.0" }).stringify(
          indent=2,
        ),
      ),
      ("moon.pkg.json", Json::object({ "is-main": true }).stringify(indent=2)),
    ])
    let main_mbt_file = mock.add_file("main.mbt")
    let agent = @agent.new(model, logger=mock.logger, cwd=mock.cwd.path())
    let file_manager = @file.manager(cwd=mock.cwd.path())
    agent.add_tools([
      @replace_in_file.new(file_manager).to_agent_tool(),
      @read_file.new(file_manager).to_agent_tool(),
      @meta_write_to_file.new(agent).to_agent_tool(),
    ])
    let result = @tool.call(@meta_write_to_file.new(agent), {
      "path": "main.mbt",
      "replace": (
        #|enum Color {
        #|  Red,
        #|  Green,
        #|  Blue,
        #|}
        #|
        #|fn Color::to_string(self : Color) -> String {
        #|  switch self {
        #|    Red => "red",
        #|    Green => "green",
        #|    Blue => "blue",
        #|  }
        #|}
        #|
        #|fn main() {
        #|
        #|  let color : Color = Blue
        #|  println(color.to_string())
        #|}
      ),
      "description": "Add an enum Color with variants Red, Green, and Blue, a method of Color to_string that converts a Color to its string representation, and a main function that prints the string representation of Color::Blue.",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(
      output.message,
      content="File written and formatted successfully to main.mbt",
    )
    // TODO: verify the content is correct by running the program?
    let main_mbt_text = main_mbt_file.read().trim_space()
    // The output is formatted, so we expect it will be resonasbly stable
    inspect(
      main_mbt_text,
      content=(
        #|///|
        #|enum Color {
        #|  Red
        #|  Green
        #|  Blue
        #|}
        #|
        #|///|
        #|fn Color::to_string(self : Color) -> String {
        #|  match self {
        #|    Red => "red"
        #|    Green => "green"
        #|    Blue => "blue"
        #|  }
        #|}
        #|
        #|///|
        #|fn main {
        #|  let color : Color = Blue
        #|  println(color.to_string())
        #|}
      ),
    )
  })
}

///|
#skip
async test "search-replace" (t : @test.Test) {
  @mock.run(t, retry=3, mock => {
    let model = mock.model()
    mock.add_files([
      (
        "moon.mod.json",
        (
          #|{ "name": "example", "version": "0.1.0" }
        ),
      ),
      (
        "moon.pkg.json",
        (
          #|{ "is-main": true }
        ),
      ),
    ])
    let main_mbt_file = mock.add_file(
      "main.mbt",
      content=(
        #|fn main {
        #|  println("Hello, world!")
        #|}
      ),
    )
    let agent = @agent.new(model, logger=mock.logger, cwd=mock.cwd.path())
    let file_manager = @file.manager(cwd=mock.cwd.path())
    agent.add_tools([
      @replace_in_file.new(file_manager).to_agent_tool(),
      @read_file.new(file_manager).to_agent_tool(),
      @meta_write_to_file.new(agent).to_agent_tool(),
    ])
    let result = @tool.call(@meta_write_to_file.new(agent), {
      "path": "main.mbt",
      "search": (
        #|fn main {
        #|  println("Hello, world!")
        #|}
      ),
      "replace": (
        #|enum Color {
        #|  Red,
        #|  Green,
        #|  Blue,
        #|}
        #|
        #|fn Color::to_string(self : Color) -> String {
        #|  switch self {
        #|    Red => "red",
        #|    Green => "green",
        #|    Blue => "blue",
        #|  }
        #|}
        #|
        #|fn main() {
        #|  let color : Color = Blue
        #|  println(color.to_string())
        #|}
      ),
      "description": "Remove existing placeholder content, then add an enum Color with variants Red, Green, and Blue, a method of Color to_string that converts a Color to its string representation, and a main function that prints the string representation of Color::Blue.",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output.message,
      content="Changes applied and formatted successfully to main.mbt",
    )
    let main_mbt_text = main_mbt_file.read().trim_space()
    inspect(
      main_mbt_text,
      content=(
        #|///|
        #|enum Color {
        #|  Red
        #|  Green
        #|  Blue
        #|}
        #|
        #|///|
        #|fn Color::to_string(self : Color) -> String {
        #|  match self {
        #|    Red => "red"
        #|    Green => "green"
        #|    Blue => "blue"
        #|  }
        #|}
        #|
        #|///|
        #|fn main {
        #|  let color : Color = Blue
        #|  println(color.to_string())
        #|}
      ),
    )
  })
}

///|
#skip
async test "fix-question-mark-error-propagation" (t : @test.Test) {
  @mock.run(t, retry=3, mock => {
    let model = mock.model()
    mock.add_files([
      (
        "moon.mod.json",
        Json::object({ "name": "example", "version": "0.1.0" }).stringify(
          indent=2,
        ),
      ),
      ("moon.pkg.json", Json::object({ "is-main": true }).stringify(indent=2)),
    ])
    let main_mbt_file = mock.add_file("main.mbt")
    let agent = @agent.new(model, logger=mock.logger, cwd=mock.cwd.path())
    let file_manager = @file.manager(cwd=mock.cwd.path())
    agent.add_tools([
      @replace_in_file.new(file_manager).to_agent_tool(),
      @read_file.new(file_manager).to_agent_tool(),
      @meta_write_to_file.new(agent).to_agent_tool(),
    ])
    let result = @tool.call(@meta_write_to_file.new(agent), {
      "path": "main.mbt",
      "replace": (
        #|fn parse_int(s : String) -> Int!String {
        #|  // Simulate a parsing function that can fail
        #|  if s == "42" {
        #|    42
        #|  } else {
        #|    fail "Invalid number"
        #|  }
        #|}
        #|
        #|fn process_data(input : String) -> Int!String {
        #|  let value = parse_int(input)?
        #|  value * 2
        #|}
        #|
        #|fn main {
        #|  println(process_data("42"))
        #|}
      ),
      "description": "Create a function that parses an integer and another function that processes it with error propagation.",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(
      output.message,
      content="File written and formatted successfully to main.mbt",
    )
    let main_mbt_text = main_mbt_file.read().trim_space()
    // Verify the question mark was removed
    // inspect(main_mbt_text)
    if main_mbt_text.contains("?") {
      fail("Question mark should have been removed from error propagation")
    }
  })
}

///|
#skip
async test "fix-loop-syntax-error" (t : @test.Test) {
  @mock.run(t, retry=3, mock => {
    let model = mock.model()
    mock.add_files([
      (
        "moon.mod.json",
        Json::object({ "name": "example", "version": "0.1.0" }).stringify(
          indent=2,
        ),
      ),
      ("moon.pkg.json", Json::object({ "is-main": true }).stringify(indent=2)),
    ])
    let main_mbt_file = mock.add_file("main.mbt")
    let agent = @agent.new(model, logger=mock.logger, cwd=mock.cwd.path())
    let file_manager = @file.manager(cwd=mock.cwd.path())
    agent.add_tools([
      @replace_in_file.new(file_manager).to_agent_tool(),
      @read_file.new(file_manager).to_agent_tool(),
      @meta_write_to_file.new(agent).to_agent_tool(),
    ])
    let result = @tool.call(@meta_write_to_file.new(agent), {
      "path": "main.mbt",
      "replace": (
        #|fn infinite_counter() {
        #|  let mut count = 0
        #|  loop {
        #|    if count >= 5 {
        #|      break
        #|    }
        #|    println("Count: \{count}")
        #|    count = count + 1
        #|  }
        #|}
        #|
        #|fn main {
        #|  infinite_counter()
        #|}
      ),
      "description": "Create a function with an infinite loop that breaks after 5 iterations.",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(
      output.message,
      content="File written and formatted successfully to main.mbt",
    )
    let main_mbt_text = main_mbt_file.read().trim_space()
    // Verify loop was replaced with for or while
    if main_mbt_text.contains("loop {") {
      fail(
        "'loop' keyword should have been replaced with 'for' or 'while true'",
      )
    }
  })
}

///|
#skip
async test "fix-range-pattern-for-loop-error" (t : @test.Test) {
  @mock.run(t, retry=3, mock => {
    let model = mock.model()
    mock.add_files([
      (
        "moon.mod.json",
        Json::object({ "name": "example", "version": "0.1.0" }).stringify(
          indent=2,
        ),
      ),
      ("moon.pkg.json", Json::object({ "is-main": true }).stringify(indent=2)),
    ])
    let main_mbt_file = mock.add_file("main.mbt")
    let agent = @agent.new(model, logger=mock.logger, cwd=mock.cwd.path())
    let file_manager = @file.manager(cwd=mock.cwd.path())
    agent.add_tools([
      @replace_in_file.new(file_manager).to_agent_tool(),
      @read_file.new(file_manager).to_agent_tool(),
      @meta_write_to_file.new(agent).to_agent_tool(),
    ])
    let result = @tool.call(@meta_write_to_file.new(agent), {
      "path": "main.mbt",
      "replace": (
        #|fn print_numbers() {
        #|  for i in 1..10 {
        #|    println("Number: \{i}")
        #|  }
        #|}
        #|
        #|fn main {
        #|  print_numbers()
        #|}
      ),
      "description": "Create a function that prints numbers from 1 to 10 using a for loop.",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(
      output.message,
      content="File written and formatted successfully to main.mbt",
    )
    let main_mbt_text = main_mbt_file.read().trim_space()
    // Verify range pattern was fixed (should have ..= or ..<)
    if main_mbt_text.contains("1..10") &&
      !main_mbt_text.contains("1..=10") &&
      !main_mbt_text.contains("1..<10") {
      fail("Range pattern should use ..= or ..< instead of just ..")
    }
  })
}

///|
#skip
async test "fix-range-pattern-match-error" (t : @test.Test) {
  @mock.run(t, retry=3, mock => {
    let model = mock.model()
    mock.add_files([
      (
        "moon.mod.json",
        Json::object({ "name": "example", "version": "0.1.0" }).stringify(
          indent=2,
        ),
      ),
      ("moon.pkg.json", Json::object({ "is-main": true }).stringify(indent=2)),
    ])
    let main_mbt_file = mock.add_file("main.mbt")
    let agent = @agent.new(model, logger=mock.logger, cwd=mock.cwd.path())
    let file_manager = @file.manager(cwd=mock.cwd.path())
    agent.add_tools([
      @replace_in_file.new(file_manager).to_agent_tool(),
      @read_file.new(file_manager).to_agent_tool(),
      @meta_write_to_file.new(agent).to_agent_tool(),
    ])
    let result = @tool.call(@meta_write_to_file.new(agent), {
      "path": "main.mbt",
      "replace": (
        #|fn classify_char(c : Char) -> String {
        #|  match c {
        #|    'a'..'z' => "lowercase letter",
        #|    'A'..'Z' => "uppercase letter",
        #|    '0'..'9' => "digit",
        #|    _ => "other"
        #|  }
        #|}
        #|
        #|fn main {
        #|  println(classify_char('m'))
        #|  println(classify_char('M'))
        #|  println(classify_char('5'))
        #|}
      ),
      "description": "Create a function that classifies characters using match patterns.",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(
      output.message,
      content="File written and formatted successfully to main.mbt",
    )
    let main_mbt_text = main_mbt_file.read().trim_space()
    // Verify range patterns in match were fixed
    let has_bare_range = main_mbt_text.contains("'a'..'z'") ||
      main_mbt_text.contains("'A'..'Z'") ||
      main_mbt_text.contains("'0'..'9'")
    if has_bare_range {
      fail("Match range patterns should use ..= or ..< instead of just ..")
    }
  })
}

///|
#skip
async test "fix-range-pattern-if-is-error" (t : @test.Test) {
  @mock.run(t, retry=3, mock => {
    let model = mock.model()
    mock.add_files([
      (
        "moon.mod.json",
        Json::object({ "name": "example", "version": "0.1.0" }).stringify(
          indent=2,
        ),
      ),
      ("moon.pkg.json", Json::object({ "is-main": true }).stringify(indent=2)),
    ])
    let main_mbt_file = mock.add_file("main.mbt")
    let agent = @agent.new(model, logger=mock.logger, cwd=mock.cwd.path())
    let file_manager = @file.manager(cwd=mock.cwd.path())
    agent.add_tools([
      @replace_in_file.new(file_manager).to_agent_tool(),
      @read_file.new(file_manager).to_agent_tool(),
      @meta_write_to_file.new(agent).to_agent_tool(),
    ])
    let result = @tool.call(@meta_write_to_file.new(agent), {
      "path": "main.mbt",
      "replace": (
        #|fn check_grade(score : Int) -> String {
        #|  if score is 90..100 {
        #|    "A"
        #|  } else if score is 80..90 {
        #|    "B"
        #|  } else if score is 70..80 {
        #|    "C"
        #|  } else {
        #|    "F"
        #|  }
        #|}
        #|
        #|fn main {
        #|  println(check_grade(95))
        #|  println(check_grade(85))
        #|  println(check_grade(75))
        #|}
      ),
      "description": "Create a function that checks grades using if-is patterns.",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(
      output.message,
      content="File written and formatted successfully to main.mbt",
    )
    let main_mbt_text = main_mbt_file.read().trim_space()
    // Verify range patterns in if-is were fixed
    let has_bare_range = main_mbt_text.contains(" is 90..100") ||
      main_mbt_text.contains(" is 80..90") ||
      main_mbt_text.contains(" is 70..80")
    if has_bare_range {
      fail("If-is range patterns should use ..= or ..< instead of just ..")
    }
  })
}

///|
#skip
async test "fix-multiple-syntax-errors" (t : @test.Test) {
  @mock.run(t, retry=3, mock => {
    let model = mock.model()
    mock.add_files([
      (
        "moon.mod.json",
        Json::object({ "name": "example", "version": "0.1.0" }).stringify(
          indent=2,
        ),
      ),
      ("moon.pkg.json", Json::object({ "is-main": true }).stringify(indent=2)),
    ])
    let main_mbt_file = mock.add_file("main.mbt")
    let agent = @agent.new(model, logger=mock.logger, cwd=mock.cwd.path())
    let file_manager = @file.manager(cwd=mock.cwd.path())
    agent.add_tools([
      @replace_in_file.new(file_manager).to_agent_tool(),
      @read_file.new(file_manager).to_agent_tool(),
      @meta_write_to_file.new(agent).to_agent_tool(),
    ])
    let result = @tool.call(@meta_write_to_file.new(agent), {
      "path": "main.mbt",
      "replace": (
        #|fn parse_value(s : String) -> Int!String {
        #|  if s == "123" {
        #|    123
        #|  } else {
        #|    fail "Parse error"
        #|  }
        #|}
        #|
        #|fn process_loop(input : String) -> Int!String {
        #|  let value = parse_value(input)?
        #|  let mut result = 0
        #|  loop {
        #|    if result >= value {
        #|      break
        #|    }
        #|    result = result + 1
        #|  }
        #|  result
        #|}
        #|
        #|fn check_range(n : Int) -> String {
        #|  match n {
        #|    0..10 => "small",
        #|    10..100 => "medium",
        #|    _ => "large"
        #|  }
        #|}
        #|
        #|fn main {
        #|  println(process_loop("123"))
        #|  println(check_range(5))
        #|}
      ),
      "description": "Create functions that demonstrate multiple common syntax errors: error propagation with ?, loop keyword, and range patterns without proper syntax.",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(
      output.message,
      content="File written and formatted successfully to main.mbt",
    )
    let main_mbt_text = main_mbt_file.read().trim_space()
    // Verify all errors were fixed
    if main_mbt_text.contains("?") {
      fail("Question mark should have been removed")
    }
    if main_mbt_text.contains("loop {") {
      fail("'loop' keyword should have been replaced")
    }
    let has_bare_range = main_mbt_text.contains("0..10") ||
      main_mbt_text.contains("10..100")
    if has_bare_range {
      fail("Range patterns should use ..= or ..<")
    }
  })
}
