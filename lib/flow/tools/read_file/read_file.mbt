///|
struct ReadFileToolResult {
  path : String
  content : String
  start_line : Int
  end_line : Int
} derive(ToJson, FromJson)

///|
pub impl Show for ReadFileToolResult with output(
  self : ReadFileToolResult,
  logger : &Logger,
) -> Unit {
  match self {
    // ReadDirectoryResult({ path, display, .. }) =>
    //   logger.write_string("Directory: \{path}\nEntries:\n\{display}")
    { path, content, start_line, end_line } => {
      let lines = content.split("\n").to_array()
      let selected_lines = lines[start_line - 1:end_line]
      let selected_content = selected_lines.join("\n")
      let range_info = "lines \{start_line}-\{end_line} (\{selected_lines.length()} lines)"
      logger.write_string("File: \{path} (\{range_info})\n\{selected_content}")
    }
  }
}

///|
test "ReadFileInput::from_json" {
  let json1 : Json = { "path": "example.mbt", "start_line": 5, "end_line": 10 }

  // ReadFileInput::from_json(@json.parse(json), "")
  let data : ReadFileInput = @json.from_json(json1)
  @json.inspect(data, content={
    "path": "example.mbt",
    "start_line": 5,
    "end_line": 10,
  })
  let json2 : Json = { "path": "example.mbt" }
  let data2 : ReadFileInput = @json.from_json(json2)
  @json.inspect(data2, content={ "path": "example.mbt" })
  let json3 : Json = { "path": "example.mbt", "start_line": 2 }
  let data3 : ReadFileInput = @json.from_json(json3)
  @json.inspect(data3, content={ "path": "example.mbt", "start_line": 2 })
  let json4 : Json = { "path": "x", "end_line": 2 }
  @json.inspect((@json.from_json(json4) : ReadFileInput), content={
    "path": "x",
    "end_line": 2,
  })
}

///|
async fn execute_read_file_tool(
  manager : @file.Manager,
  args : Json,
) -> @tool.ToolResult[ReadFileToolResult] noraise {
  // Parse required path parameter
  let { path, start_line, end_line } : ReadFileInput = @json.from_json(args) catch {
    error =>
      return @tool.error(
        "Error: Invalid arguments provided to read_file tool: \{error}",
        error~,
      )
  }
  try {
    // Resolve file path
    let resolved_path = if @path.is_absolute(path) {
      path.view()
    } else {
      @path.join(manager.cwd, path)
    }
    let resolved_path = @path.resolve(resolved_path)

    // Check if file exists
    if !@fsx.exists(resolved_path) {
      return @tool.error("Error reading file: File not found: \{path}")
    }
    if @fsx.kind(resolved_path) is Directory {
      return @tool.error("Error reading file: Path is a directory: \{path}")
    }

    // Open and read the file
    let content = @fsx.read_file(resolved_path)

    // Update access time
    let stat = @fsx.stat(resolved_path)
    manager.access[resolved_path] = stat.atime()

    // Process line range parameters
    let lines = content.split("\n").to_array()
    let start_line = match start_line {
      Some(n) =>
        if n < 1 {
          return @tool.error("Error: start_line must be >= 1, got \{n}")
        } else if n > lines.length() {
          return @tool.error(
            "Error: start_line (\{n}) must be <= total lines (\{lines.length()}), got \{n}",
          )
        } else {
          n
        }
      None => 1
    }
    let end_line = match end_line {
      Some(end_line) => {
        if end_line < 1 {
          return @tool.error("Error: end_line must be >= 1, got \{end_line}")
        }
        if end_line <= start_line {
          return @tool.error(
            "Error: end_line (\{end_line}) must be greater than start_line (\{start_line})",
          )
        }
        if end_line > lines.length() {
          lines.length()
        } else {
          end_line
        }
      }
      None => lines.length()
    }
    return @tool.ok({ path, content, start_line, end_line })
  } catch {
    error => @tool.error("Error reading file: \{error}", error~)
  }
}

///|
pub fn new(manager : @file.Manager) -> @tool.Tool[ReadFileToolResult] {
  @tool.new(
    description="Read the contents of a file at the specified path. Use this when you need to examine the contents of an existing file, for example to analyze code, review text files, or extract information from configuration files. For very large files (>30k tokens), the tool will automatically extract relevant sections based on the provided query to manage token usage efficiently. Supports reading specific line ranges with [start_line, end_line) format (1-indexed, end_line exclusive).",
    name="read_file",
    schema~,
    @tool.ToolFn(async fn(
      args,
    ) -> @tool.ToolResult[ReadFileToolResult] noraise {
      execute_read_file_tool(manager, args)
    }),
  )
}
