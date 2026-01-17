///|
priv struct ReadFileResult {
  path : String
  content : String
  start_line : Int
  end_line : Int
} derive(ToJson, @json.FromJson)

///|
priv struct ReadDirectoryResult {
  path : String
  entries : Array[String]
  display : String
} derive(ToJson, @json.FromJson)

///|
priv enum ReadFileToolResult {
  ReadFileResult(ReadFileResult)
  ReadDirectoryResult(ReadDirectoryResult)
} derive(ToJson, @json.FromJson)

///|
/// 
/// wrapper type in order to override the Show trait result 
struct ReadMultipleFilesResult(Array[ReadFileToolResult]) derive (
  ToJson,
  @json.FromJson,
)

///|
pub impl Show for ReadMultipleFilesResult with output(self, logger) {
  for content in self.0 {
    logger.write_object(content)
    logger.write_string("\n\n")
  }
}

///|
impl Show for ReadFileToolResult with output(
  self : ReadFileToolResult,
  logger : &Logger,
) -> Unit {
  match self {
    ReadDirectoryResult({ path, display, .. }) =>
      logger.write_string("Directory: \{path}\nEntries:\n\{display}")
    ReadFileResult({ path, content, start_line, end_line }) => {
      let lines = content.split("\n").to_array()
      let selected_lines = lines[start_line - 1:end_line]
      let selected_content = selected_lines.join("\n")
      let range_info = "lines \{start_line}-\{end_line} (\{selected_lines.length()} lines)"
      logger.write_string("File: \{path} (\{range_info})\n\{selected_content}")
    }
  }
}

///|
async fn execute_read_file_tool(
  manager : @file.Manager,
  args : Json,
) -> @tool.ToolResult[ReadFileToolResult] noraise {
  // Parse required path parameter
  guard args is { "path": String(path), .. } else {
    return @tool.error("Error: 'path' parameter is required")
  }
  let start_line : Int? = match args {
    { "start_line": Number(n, ..), .. } => Some(n.to_int())
    _ => None
  }
  let end_line : Int? = match args {
    { "end_line": Number(n, ..), .. } => Some(n.to_int())
    _ => None
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
      let entries = @fsx.list_directory(resolved_path).map(entry => match
        entry.kind {
        Directory => "\{entry.name}\{@path.sep}"
        Regular => entry.name
        _ => entry.name
      })
      let display = entries.join("\n")
      return @tool.ok(
        ReadDirectoryResult(ReadDirectoryResult::{ path, entries, display }),
      )
    }

    // Open and read the file
    let content = @fsx.read_file(resolved_path)

    // Update access time
    let stat = @fsx.stat(resolved_path)
    manager.access[resolved_path] = stat.atime()

    // Process line range parameters
    let lines = content.split("\n").to_array()
    let start_line = match start_line {
      Some(n) if n >= 1 => n
      Some(n) => return @tool.error("Error: start_line must be >= 1, got \{n}")
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
    return @tool.ok(
      ReadFileResult(ReadFileResult::{ path, content, start_line, end_line }),
    )
  } catch {
    error => @tool.error("Error reading file: \{error}", error~)
  }
}

///|
priv suberror MultipleErrors Array[(Error, String)] derive(Show, ToJson)

///|
fn to_path(rdr : ReadFileToolResult) -> String {
  match rdr {
    ReadFileResult({ path, .. }) => path
    ReadDirectoryResult({ path, .. }) => path
  }
}

///|
async fn execute_read_multiple_files_tool(
  manager : @file.Manager,
  args : Json,
) -> @tool.ToolResult[ReadMultipleFilesResult] noraise {
  guard args is { "files": Array(paths_json), .. } else {
    return @tool.error(
      "Error: parameter is required be object with 'files' key, value is an array of { path: string; start_line?: number; end_line?: number; }",
    )
  }
  let results = []
  let errs = []
  for args in paths_json {
    let result = execute_read_file_tool(manager, args)
    match result {
      Ok(val) => results.push(val)
      Error(err, msg) => errs.push((err, msg))
    }
  }
  if errs.is_empty() {
    results.sort_by_key(to_path)
    @tool.ok(ReadMultipleFilesResult(results))
  } else {
    @tool.error(errs.map(x => x.1).join("\n"), error=MultipleErrors(errs))
  }
}

///|
pub fn new(manager : @file.Manager) -> @tool.Tool[ReadMultipleFilesResult] {
  let description =
    #| Read the contents of multiple files at the specified paths.
    #| Use this when you need to examine the contents of existing files,
    #| for example to analyze code, review text files,
    #| or extract information from configuration files.
    #|
    #| For very large files (>30k tokens),
    #| the tool will automatically extract relevant sections based on the provided query to manage token usage efficiently.
    #| Supports reading specific line ranges with [start_line, end_line) format (1-indexed, end_line exclusive).
  @tool.new(
    description~,
    name="read_multiple_files",
    schema~,
    @tool.ToolFn(async fn(
      args,
    ) -> @tool.ToolResult[ReadMultipleFilesResult] noraise {
      execute_read_multiple_files_tool(manager, args)
    }),
  )
}
