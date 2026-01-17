///|
priv struct ReadFileInput {
  path : String
  start_line : Int?
  end_line : Int?
} derive(FromJson, ToJson)

///|
/// The schema is derived from the types above
/// TODO: automate this process
let schema : @tool.JsonSchema = {
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "The path of the file to read, relative to the current working directory",
    },
    "start_line": {
      "type": "number",
      "description": "Optional starting line number (1-indexed, inclusive). When specified with end_line, only reads the specified line range.",
    },
    "end_line": {
      "type": "number",
      "description": "Optional ending line number (1-indexed, exclusive). When specified with start_line, only reads the specified line range.",
    },
  },
  "required": ["path"],
}
