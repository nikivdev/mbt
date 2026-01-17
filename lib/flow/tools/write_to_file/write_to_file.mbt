///|
let schema : @tool.JsonSchema = @tool.JsonSchema::from_json({
  "type": "object",
  "properties": {
    "content": {
      "type": "string",
      "description": "The content to write to the file.",
    },
    "path": {
      "type": "string",
      "description": "The path of the file to write to, relative to the current working directory.",
    },
    "separator": {
      "type": "string",
      "description": "Optional separator to add between existing content and new content (default: newline).",
      "default": "\n",
    },
  },
  "required": ["path", "content"],
})

///|
priv struct Params {
  content : String // required
  path : String // required
  separator : String?
} derive(ToJson, FromJson)

///|
fn params(content~ : String, path~ : String, separator? : String) -> Params {
  Params::{ content, path, separator }
}

///|
pub fn json_input(
  content~ : String,
  path~ : String,
  separator? : String,
) -> Json {
  params(content~, path~, separator?).to_json()
}

///|
test {
  @json.inspect(
    params(content="Hello, World!", path="example.txt", separator="\n"),
    content={
      "content": "Hello, World!",
      "path": "example.txt",
      "separator": "\n",
    },
  )
}

///|
struct Result {
  path : String
} derive(FromJson, ToJson)

///|
pub impl Show for Result with output(self : Result, logger : &Logger) -> Unit {
  logger.write_string("Content written to file at path: \{self.path}")
}

///|
pub fn new(cwd : String) -> @tool.Tool[Result] {
  @tool.new(
    description="Write content to a file at the specified path. If the file doesn't exist, it will be created. If the file exists, the content will be appended. This tool will automatically create any directories needed to write the file.",
    name="write_to_file",
    schema~,
    async fn(args) -> @tool.ToolResult[Result] noraise {
      let { path, separator, content } : Params = @json.from_json(args) catch {
        error => return @tool.error("Invalid arguments: \{error}")
      }
      let path = if @path.is_absolute(path) {
        path
      } else {
        @path.join(cwd, path)
      }
      let separator = separator.unwrap_or("\n")
      let content_to_append = if (@fsx.exists(path) catch {
          error =>
            return @tool.error("Failed to check if file exists: \{error}")
        }) {
        let existing_content = @fsx.read_file(path) catch {
          error => return @tool.error("Failed to read existing file: \{error}")
        }
        if existing_content.is_empty() {
          content
        } else {
          existing_content + separator + content
        }
      } else {
        content
      }
      let _ = @fsx.write_to_file(path, content_to_append) catch {
        error => return @tool.error("Failed to write to file: \{error}")
      }
      let result = Result::{ path, }
      @tool.ok(result)
    },
  )
}
