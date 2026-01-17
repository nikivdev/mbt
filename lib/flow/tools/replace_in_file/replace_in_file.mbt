///|
priv enum WriteResultOperation {
  Created
  Updated
  Replaced
} derive(ToJson, FromJson)

///|
/// Write operation result for structured JSON output
struct WriteResult {
  path : String
  operation : WriteResultOperation
  bytes_written : Int
  search_used : Bool
  message : String
  content : String
} derive(ToJson, FromJson)

///|
pub impl Show for WriteResult with output(self : WriteResult, logger : &Logger) -> Unit {
  logger.write_string(self.message)
}

///|
/// Main execution function for the replace_in_file tool
async fn @file.Manager::execute_replace_in_file(
  self : @file.Manager,
  args : Json,
) -> @tool.ToolResult[WriteResult] noraise {
  let { path, replace, search } : Input = @json.from_json(args) catch {
    error =>
      return @tool.error(
        "Error: Invalid arguments provided to replace_in_file tool: \{error}",
        error~,
      )
  }
  try {
    // Resolve file path relative to current working directory
    let resolved_path = if @path.is_absolute(path) {
      path
    } else {
      @path.join(self.cwd, path)
    }
    let resolved_path = @path.resolve(resolved_path)

    // Check if file exists
    guard @fsx.exists(resolved_path) else {
      // Create directory if it doesn't exist
      @fsx.make_directory(
        @path.dirname(resolved_path),
        recursive=true,
        exists_ok=true,
      )

      // File doesn't exist, create new file with replace content
      @fsx.write_to_file(resolved_path, replace)
      let result = WriteResult::{
        path,
        operation: Created,
        bytes_written: replace.length(),
        search_used: false,
        message: "New file created and content written to \{path}",
        content: replace,
      }
      @tool.ok(result)
    }

    // Read existing file content
    let content = match search {
      None =>
        // No search provided, replace entire file content
        replace
      Some(search_content) => {
        let content = @fsx.read_file(resolved_path)
        // Search and replace operation
        match @fuzzy.find_match(content, search_content) {
          None =>
            return @tool.error(
              "Search content not found in file (tried all matching strategies): \{search_content}",
            )
          Some(match_result) => {
            // Replace at the exact position to maintain formatting
            let before = content[0:match_result.position].to_string()
            let after = content[match_result.position + match_result.length:].to_string()
            before + replace + after
          }
        }
      }
    }

    // Write the modified content back to file
    @fsx.write_to_file(resolved_path, content)
    let operation = match search {
      None => Replaced
      Some(_) => Updated
    }
    let result = WriteResult::{
      path,
      operation,
      bytes_written: content.length(),
      search_used: search is Some(_),
      message: "Changes applied to \{path}",
      content,
    }
    @tool.ok(result)
  } catch {
    error => @tool.error("Error writing to file: \{error}", error~)
  }
}

///|
pub fn new(manager : @file.Manager) -> @tool.Tool[WriteResult] {
  @tool.new(
    description="Write content to a file at the specified path using search/replace operation. For new files, provide only a replace parameter. For existing files, the search content must match exactly. This tool will automatically create any directories needed to write the file.",
    name="replace_in_file",
    schema~,
    async fn(args) -> @tool.ToolResult[WriteResult] noraise {
      manager.execute_replace_in_file(args)
    },
  )
}
