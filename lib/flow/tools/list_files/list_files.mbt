///|
/// File entry with metadata for enhanced list_files output
priv struct FileEntry {
  name : String
  kind : String // "file", "directory", "symlink", etc.
  size : Int? // Size in bytes for files, None for directories
  is_hidden : Bool
} derive(ToJson, FromJson)

///|
/// Enhanced list_files result with metadata
struct ListFilesResult {
  path : String
  entries : Array[FileEntry]
  total_count : Int
  file_count : Int
  directory_count : Int
} derive(ToJson, FromJson)

///|
pub impl Show for ListFilesResult with output(
  result : ListFilesResult,
  logger : &Logger,
) -> Unit {
  if result.total_count == 0 {
    return logger.write_string("No files found.")
  }
  let output = []
  output.push("Directory: \{result.path}")
  output.push(
    "Total: \{result.total_count} items (\{result.file_count} files, \{result.directory_count} directories)",
  )
  output.push("")
  for entry in result.entries {
    let prefix = match entry.kind {
      "directory" => "📁"
      "file" => "📄"
      "symlink" => "🔗"
      _ => "❓"
    }
    let size_info = match entry.size {
      Some(size) => " (\{size} bytes)"
      None => ""
    }
    let hidden_marker = if entry.is_hidden { " [hidden]" } else { "" }
    output.push("\{prefix} \{entry.name}\{size_info}\{hidden_marker}")
  }
  logger.write_string(output.join("\n"))
}

///|
async fn execute_list_files(
  manager : @file.Manager,
  path : String,
) -> ListFilesResult {
  let resolved_path = if @path.is_absolute(path) {
    path.view()
  } else {
    @path.join(manager.cwd, path)
  }
  let resolved_path = @path.resolve(resolved_path)
  let entries = @fsx.list_directory(resolved_path)
  let mut file_count = 0
  let mut directory_count = 0
  let file_entries = []
  for entry in entries {
    let kind_str = match entry.kind {
      Regular => {
        file_count += 1
        "file"
      }
      Directory => {
        directory_count += 1
        "directory"
      }
      SymLink => "symlink"
      _ => "other"
    }
    let is_hidden = entry.name.has_prefix(".")
    let size = None
    file_entries.push(FileEntry::{
      name: entry.name,
      kind: kind_str,
      size,
      is_hidden,
    })
  }
  ListFilesResult::{
    path,
    entries: file_entries,
    total_count: file_entries.length(),
    file_count,
    directory_count,
  }
}

///|
pub fn new(manager : @file.Manager) -> @tool.Tool[ListFilesResult] {
  @tool.new(
    description="List files in a directory",
    name="list_files",
    schema~,
    async fn(args) -> @tool.ToolResult[ListFilesResult] noraise {
      let { path } : InputPath = @json.from_json(args) catch {
        // TODO(upstream): weird error when missing `_ => `
        _ => return @tool.error("Error: 'path' parameter is required")
      }
      let result = execute_list_files(manager, path) catch {
        error => return @tool.error("Error listing files: \{error}")
      }
      @tool.ok(result)
    },
  )
}
