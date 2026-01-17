///|
let schema : @tool.JsonSchema = @tool.JsonSchema::from_json({
  "type": "object",
  "properties": {
    "context_lines": {
      "type": "number",
      "description": "Number of context lines to show before and after each match. Defaults to 2.",
      "default": 2,
    },
    "file_pattern": {
      "type": "string",
      "description": "Glob pattern to filter files (e.g., '*.ts', '*.js', '*.py', etc.). Defaults to '*' to search all files.",
      "default": "*",
    },
    "kind": {
      "type": "string",
      "enum": ["regex", "moonbit_definition", "moonbit_references"],
      "description": "The kind of search to perform. 'regex' performs traditional regex-based file content search. 'moonbit_definition' performs fuzzy symbolic search to find MoonBit symbol definitions - note that when using 'moonbit_definition', the regex parameter can be imprecise as the system will perform fuzzy search to find the most relevant symbols. 'moonbit_references' finds all references to a MoonBit symbol using the moon IDE tool.",
    },
    "path": {
      "type": "string",
      "description": "The path of the directory or file to search in, relative to the current working directory.",
    },
    "regex": {
      "type": "string",
      "description": "The search pattern. For 'regex' kind: regular expression pattern with full regex syntax. For 'moonbit_definition' kind: symbol name or partial name (can be imprecise) for fuzzy symbolic search.",
    },
    "respect_gitignore": {
      "type": "boolean",
      "description": "Whether to respect .gitignore files when searching. Defaults to true.",
      "default": true,
    },
  },
  "required": ["path", "regex", "kind"],
})
