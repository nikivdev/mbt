///|
/// Tool for the sub-agent to submit fixed code segments
let submit_schema : @tool.JsonSchema = {
  "type": "object",
  "properties": {
    "content": {
      "type": "string",
      "description": "The complete fixed file content",
    },
  },
  "required": ["content"],
}

///|
priv struct InputSubmit {
  content : String
} derive(FromJson)

///|
/// Tool for the sub-agent to signal completion
let completion_schema : @tool.JsonSchema = {
  "type": "object",
  "properties": {
    "result": {
      "type": "string",
      "description": "Summary of the fixing result",
    },
  },
  "required": ["result"],
}

///|
priv struct InputCompletion {
  result : String
} derive(FromJson)

///|
/// The meta_write_to_file tool definition
let meta_schema : @tool.JsonSchema = {
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "The path of the file to write to, relative to the current working directory.",
    },
    "search": {
      "type": "string",
      "description": "The content to search for. If not provided, the entire file will be replaced with the replace content.",
    },
    "replace": {
      "type": "string",
      "description": "The content to replace with. If search is not provided, this will be the entire file content. If replace is empty string, the matched content will be deleted.",
    },
    "description": {
      "type": "string",
      "description": "A natural language description of what you're trying to accomplish with this file write operation. This helps the sub-agent understand the intent when fixing syntax errors.",
    },
  },
  "required": ["path", "description", "replace"],
}

///|
/// Parameters for the meta_write_to_file tool
priv struct MetaWriteParams {
  path : String
  search : String?
  replace : String
  description : String
} derive(FromJson)
