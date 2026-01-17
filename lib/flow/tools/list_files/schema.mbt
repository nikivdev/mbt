///|
let schema : @tool.JsonSchema = {
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "The path to list files from, relative to the current working directory",
    },
  },
  "required": ["path"],
}

///|
priv struct InputPath {
  path : String
} derive(FromJson)
