///|
priv struct Formatter {
  recover_diagnostics : Bool
  /// Output markdown file path.
  path : String
  /// Tool ID if this is a sub-formatter.
  id : String?
  /// Number of messages in this log.
  mut count : Int
  /// Formatted lines.
  lines : Array[String]
  /// Tool-specific logs are formatted using sub-formatters.
  tools : Map[String, Formatter]
  /// Versions of fixed files submitted in this subagent.
  submit_fixed_files : Array[String]
  mut start_timestamp : Int64?
}

///|
fn Formatter::new(
  path : String,
  recover_diagnostics? : Bool = false,
) -> Formatter {
  Formatter::{
    recover_diagnostics,
    path,
    id: None,
    count: 1,
    lines: [],
    tools: {},
    submit_fixed_files: [],
    start_timestamp: None,
  }
}

///|
fn Formatter::to_string(self : Formatter) -> String raise {
  let string = self.lines.join("\n")
  // Recover diagnostics only if this is a sub-formatter
  if self.id is Some(_) && self.recover_diagnostics {
    return recover_diagnostics(string)
  } else {
    return string
  }
}

///|
fn Formatter::push_title(
  self : Formatter,
  title : String,
  level? : Int,
  numbered? : Bool = false,
  timestamp? : Int64,
) -> Unit raise {
  let prefix = "#".repeat(level.unwrap_or(1))
  let title = if numbered {
    let title = "\{prefix} \{self.count} \{title}"
    self.count += 1
    title
  } else {
    "\{prefix} \{title}"
  }
  self.lines.push(title)
  if timestamp is Some(timestamp) {
    self.lines.push("")
    self.format_timestamp(timestamp~)
  }
}

///|
fn Formatter::format_tool_call_as_xml(
  self : Formatter,
  name : String,
  args : Json,
) -> Unit raise {
  // Some heuristic formatting for common tool call arguments
  if args is { "path": String(path), .. } {
    self.push_title(
      "Tool call argument: <\{name} path=\{path.escape()}>",
      level=2,
    )
  } else if args is { "command": String(command), .. } {
    self.push_title(
      "Tool call argument: <\{name} command=\{command.escape()}>",
      level=2,
    )
  } else {
    self.push_title("Tool call argument: <\{name}>", level=2)
  }
  self.lines.push("")
  json2xml(args, self.lines)
}

///|
async fn Formatter::format_replace_in_file(
  self : Formatter,
  name : String,
  args : Json,
) -> Unit {
  match args {
    {
      "path": String(path),
      "search": String(search),
      "replace": String(replace),
      ..
    } => {
      self.push_title(
        "Tool call argument: <\{name} path=\{path.escape()}>",
        level=2,
      )
      self.lines.push("")
      self.lines.push("```diff")
      self.lines.push(@git.generate_git_diff(original=search, modified=replace))
      self.lines.push("```")
    }
    { "path": String(path), "replace": String(replace), .. } => {
      self.push_title(
        "Tool call argument: <\{name} path=\{path.escape()}>",
        level=2,
      )
      self.lines.push("")
      let file_format = if path.has_suffix(".mbt") {
        "moonbit"
      } else if path.has_suffix(".json") {
        "json"
      } else if path.has_suffix(".md") {
        "markdown"
      } else {
        "plaintext"
      }
      if file_format is "markdown" {
        self.lines.push("````\{file_format}")
        self.lines.push(replace)
        self.lines.push("````")
      } else {
        self.lines.push("```\{file_format}")
        self.lines.push(replace)
        self.lines.push("```")
      }
    }
    _ => self.format_tool_call_as_xml(name, args)
  }
}

///|
async fn Formatter::format_submit_fixed_file(
  self : Formatter,
  name : String,
  args : Json,
) -> Unit {
  match args {
    { "content": String(content), .. } => {
      self.push_title("Tool call argument: <\{name}>", level=2)
      self.lines.push("")
      self.lines.push("Submitting fixed file content:")
      self.lines.push("")
      if self.submit_fixed_files.last() is Some(last_content) {
        self.submit_fixed_files.push(content)
        let diff = @git.generate_git_diff(
          original=last_content,
          modified=content,
          line_number=true,
        )
        self.lines.push("```diff")
        self.lines.push(diff)
        self.lines.push("```")
      } else {
        self.submit_fixed_files.push(content)
        self.lines.push("```moonbit")
        self.lines.push(content)
        self.lines.push("```")
      }
    }
    _ => self.format_tool_call_as_xml(name, args)
  }
}

///|
/// Formats tool call from a MessageAdded log entry.
async fn Formatter::format_tool_call(
  self : Formatter,
  tool_call : @openai.ChatCompletionMessageToolCall,
) -> Unit {
  guard tool_call.function.arguments is Some(arguments) else {
    self.push_title("Tool call argument: <\{tool_call.function.name}>", level=2)
    self.lines.push("")
    self.lines.push("No arguments provided.")
    self.lines.push("")
    return
  }
  try @json.parse(arguments) catch {
    error => {
      self.push_title(
        "Tool call argument: <\{tool_call.function.name}>",
        level=2,
      )
      self.lines.push("")
      self.lines.push("Failed to parse tool call arguments as JSON: \{error}")
      self.lines.push("")
      self.lines.push("```json")
      self.lines.push(arguments)
      self.lines.push("```")
    }
  } noraise {
    args => {
      if tool_call.function.name is ("replace_in_file" | "meta_write_to_file") {
        self.format_replace_in_file(tool_call.function.name, args)
      } else if tool_call.function.name is "submit_fixed_file" {
        self.format_submit_fixed_file(tool_call.function.name, args)
      } else {
        self.format_tool_call_as_xml(tool_call.function.name, args)
      }
      self.lines.push("")
      self.push_title("Original JSON payload", level=3)
      self.lines.push("")
      self.lines.push("```json")
      self.lines.push(args.stringify(indent=2))
      self.lines.push("```")
    }
  }
  self.lines.push("")
}

///|
/// Number of context lines to show for recovered diagnostics. 1 means 1 line
/// before and 1 line after.
const ContextLines = 1

///|
/// Recovers diagnostic context from file content embedded in the log.
fn recover_diagnostics(content : String) -> String raise {
  let lines = content.split("\n").collect()
  // 1. Collect source
  let source = StringBuilder::new()
  // Matches lines like this
  //
  // `````
  // # 3 Tool call result: <read_file>
  //
  // ````markdown
  // File content:
  // <moonbit-source>
  // `````
  loop lines[:] {
    [title, "", "````markdown", "File content:", .. rest] if title.has_suffix(
        "Tool call result: <read_file>",
      ) =>
      continue source~: loop rest {
          ["````", .. rest] => break rest
          [line, .. rest] => {
            source.write_string([..line, '\n'])
            continue source~ rest
          }
          [] => break []
        }
    [_, .. rest] => continue rest
    [] => break
  }
  let source_lines = source.to_string().split("\n").collect()
  // 2. Recover diagnostics
  let recovered = []
  loop lines[:] {
    [] => break
    [line, .. rest] => {
      recovered.push(line)
      // Matches
      // error[<code>]: <file>:<line>:<column>: ...
      lexmatch line with longest {
        (
          "error\["
          "\d{4}"
          "\]:\s+"
          "[^:]*"
          ":"
          ("\d+" as line)
          ":"
          ("\d+" as column)
          ":\s+",
          _
        ) => {
          let line = @strconv.parse_int(line) - 1
          let context_start = @cmp.maximum(0, line - ContextLines)
          let context_end = @cmp.minimum(
            source_lines.length() - 1,
            line + ContextLines,
          )
          let column = @strconv.parse_int(column)
          let line_number = (line + 1).to_string()
          let line_number_width = (line + 1).to_string().length()
          let indent = " ".repeat(line_number_width)
          for i in context_start..<line {
            recovered.push("\{indent} │\{source_lines[i]}")
          }
          recovered.push("\{line_number} │\{source_lines[line]}")
          let padding = " ".repeat(column - 1)
          recovered.push("\{indent} │\{padding}^")
          for i in (line + 1)..=context_end {
            recovered.push("\{indent} │\{source_lines[i]}")
          }
        }
        _ => ()
      }
      continue rest
    }
  }
  recovered.join("\n")
}

///|
fn Formatter::format_timestamp(
  self : Formatter,
  timestamp~ : Int64,
) -> Unit raise {
  let seconds = timestamp / 1000
  let timestamp = @time.unix(seconds).to_plain_time().to_string()
  self.lines.push(timestamp)
}

///|
/// Formats a MessageAdded log entry.
async fn Formatter::format_message_added(
  self : Formatter,
  message : @openai.ChatCompletionMessageParam,
  timestamp? : Int64,
) -> Unit {
  // Tool is already handled when formatting PostToolCall
  if message is Tool(_) {
    return
  }
  let role = openai_message_role(message)
  let content = openai_message_content(message)
    .trim(char_set=" \n\r\t")
    .to_string()
  if message is System(_) {
    self.push_title(role, numbered=true, timestamp?)
    self.lines.push("")
    // We need to wrap the system message in code fence to avoid polluting the
    // markdown structure.
    let backticks = "`".repeat(
      @cmp.maximum(3, count_maximum_contiguous_backticks(content) + 1),
    )
    self.lines.push("\{backticks}markdown")
    self.lines.push(content)
    self.lines.push("\{backticks}")
    self.lines.push("")
    return
  }
  let title = content.split("\n").drop_while(line => line.is_blank()).peek()
  if title is Some(first_line) {
    self.push_title("\{role}: \{first_line}", numbered=true, timestamp?)
    self.lines.push("")
    self.lines.push(content)
    self.lines.push("")
  } else {
    self.push_title(role, numbered=true, timestamp?)
    if !content.is_empty() {
      self.lines.push("")
      self.lines.push(content)
    }
    self.lines.push("")
  }
  if self.id is Some(_) && message is User(_) {
    let lines = []
    loop content.split("\n").collect()[:] {
      ["**File Content:**", "", "```moonbit", .. rest] =>
        continue source~: loop rest {
            ["```", .. rest] => break rest
            [line, .. rest] => {
              lines.push(line)
              continue source~ rest
            }
            [] => break []
          }
      [_, .. rest] => continue rest
      [] => break
    }
    let original_content = lines.join("\n")
    if !original_content.is_blank() {
      self.submit_fixed_files.push(original_content)
    }
  }
}

///|
fn Formatter::format_post_tool_call(
  self : Formatter,
  name : String,
  result? : Result[Json, Json],
  text : String,
  timestamp? : Int64,
) -> Unit raise {
  if result is Some(Ok(result)) {
    match (name, result) {
      (
        "execute_command",
        [
          "Completed",
          { "command": String(command), "status": Number(status, ..), .. },
          ..,
        ],
      ) =>
        if status == 0 {
          self.push_title(
            "Tool call result: <\{name} command=\{command.escape()}>",
            numbered=true,
            timestamp?,
          )
        } else {
          self.push_title(
            "❌ Tool call error: <\{name} command=\{command.escape()}>",
            numbered=true,
            timestamp?,
          )
        }
      ("list_files", { "path": String(path), .. })
      | ("read_file", ["ReadFileResult", { "path": String(path), .. }, ..])
      | ("replace_in_file", { "path": String(path), .. })
      | ("meta_write_to_file", { "path": String(path), .. }) =>
        self.push_title(
          "Tool call result: <\{name} path=\{path.escape()}>",
          numbered=true,
          timestamp?,
        )
      _ =>
        self.push_title(
          "Tool call result: <\{name}>",
          numbered=true,
          timestamp?,
        )
    }
  } else if result is Some(Err(_)) {
    self.push_title("❌ Tool call error: <\{name}>", numbered=true, timestamp?)
  } else {
    self.push_title("Tool call result: <\{name}>", numbered=true, timestamp?)
  }
  self.lines.push("")
  self.lines.push("````markdown")
  self.lines.push(text)
  self.lines.push("````")
  self.lines.push("")
}

///|
/// Formats a log entry from JSON.
async fn Formatter::format_log_entry(self : Formatter, json : Json) -> Unit {
  // Extract timestamp if available
  let timestamp = match json {
    { "time": Number(timestamp, repr=None), .. } => Some(timestamp.to_int64())
    { "time": Number(_, repr=Some(timestamp)), .. } =>
      Some(@strconv.parse_int64(timestamp)) catch {
        _ => None
      }
    _ => None
  }
  let timestamp : Int64? = if timestamp is Some(ts) {
    if self.start_timestamp is Some(start_timestamp) {
      Some(ts - start_timestamp)
    } else {
      self.start_timestamp = Some(ts)
      Some(0)
    }
  } else {
    None
  }
  if self.id is None &&
    json is { "tool": { "name": String(name), "id": String(id), .. }, .. } {
    // If we found a log entry with "tool" field, delegate to sub-formatter,
    // create if there is no matching sub-formatter.
    match self.tools.get(id) {
      Some(formatter) => {
        formatter.format_log_entry(json)
        return
      }
      None => {
        // No sub-formatter found, create a new one and link to the sub-log file
        // in the main log.
        let dirname = @path.dirname(self.path)
        let filename = {
          let basename = @path.basename(self.path)
          "\{basename}-\{id}.md"
        }
        let path = @path.join(dirname, filename)
        let formatter = Formatter::{
          recover_diagnostics: self.recover_diagnostics,
          path,
          id: Some(id),
          count: 1,
          lines: [],
          tools: {},
          submit_fixed_files: [],
          start_timestamp: None,
        }
        self.tools.set(id, formatter)
        self.push_title("🤖 Spawned subagent for tool: <\{name}>", level=2)
        self.lines.push("")
        self.lines.push("[<\{name}> log](\{filename})")
        self.lines.push("")
        formatter.format_log_entry(json)
        return
      }
    }
  }
  match json {
    { "msg": "RequestCompleted", "message": message, .. } => {
      let message : @openai.ChatCompletionMessage = @json.from_json(message)
      let content = message.content
        .unwrap_or("")
        .trim(char_set=" \n\r\t")
        .to_string()
      let title = content.split("\n").drop_while(line => line.is_blank()).peek()
      if title is Some(title) {
        self.push_title("Assistant: \{title}", numbered=true, timestamp?)
        self.lines.push("")
        self.lines.push(content)
        self.lines.push("")
      } else {
        self.push_title("Assistant", numbered=true, timestamp?)
        if !content.is_empty() {
          self.lines.push("")
          self.lines.push(content)
        }
        self.lines.push("")
      }
      if message.tool_calls.length() > 0 {
        for tool_call in message.tool_calls {
          self.format_tool_call(tool_call)
        }
      }
    }
    { "msg": "PostToolCall", "name": String(name), "text": String(text), .. } =>
      if json is { "result": result, .. } {
        self.format_post_tool_call(name, result=Ok(result), text, timestamp?)
      } else if json is { "error": error, .. } {
        self.format_post_tool_call(name, result=Err(error), text, timestamp?)
      } else {
        self.format_post_tool_call(name, text, timestamp?)
      }
    { "msg": "MessageAdded", "message": message, .. } => {
      let message : @openai.ChatCompletionMessageParam = @json.from_json(
        message,
      )
      self.format_message_added(message, timestamp?)
    }
    { "msg": "ModelLoaded", "name": String(name) | [String(name)], .. } => {
      self.push_title("System information", timestamp?)
      self.lines.push("")
      self.lines.push("Model: \{name}")
      self.lines.push("")
    }
    _ => ()
  }
}
