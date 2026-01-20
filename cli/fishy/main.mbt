///|
/// fishy - create fish wrappers quickly
///
/// Usage:
///   fishy wrap <command...> [for|as|named|to] <name>
///   fishy <command...> [for|as|named|to] <name>
///   fishy agent <fish request...>
///   fishy -h | --help
///
/// Examples:
///   fishy wrap zed-open code for we
///   fishy hive agent fish to fa

let program_name = "fishy"
let target_file = "/Users/nikiv/config/fish/fn.fish"
let program_version = "0.2.0"
let default_lm_model = "zai-org/glm-4.7-flash"
let default_lm_port = 1234

struct ParsedWrap {
  cmd : String
  wraps_cmd : String
  wrapper : String
}

async fn main {
  let args = @sys.get_cli_args()
  if args.length() <= 1 {
    print_usage()
    return
  }
  let first = args[1]
  if first == "-h" || first == "--help" {
    print_usage()
    return
  }
  if first == "--version" || first == "-v" {
    println("\{program_name} \{program_version}")
    return
  }
  if first == "reload" {
    println("Run: source /Users/nikiv/config/fish/fn.fish")
    return
  }
  if first == "agent" || first == "smart" {
    let prompt = join_args(args, 2)
    if prompt.length() == 0 {
      print_usage()
      return
    }
    let action = infer_action(prompt)
    match action {
      None => {
        println("Could not infer fish action")
        return
      }
      Some(act) => {
        let script = build_action_script(act)
        let result = run_shell(script, ".")
        if result.stdout.length() > 0 {
          println(result.stdout.trim())
        }
        if result.stderr.length() > 0 {
          println(result.stderr.trim())
        }
        return
      }
    }
  }
  if first.has_prefix("-") {
    print_usage()
    return
  }

  let tokens = args_slice(args, 1)
  let parsed = parse_wrap(tokens)
  match parsed {
    None => {
      println("Usage: \{program_name} wrap <command...> [for|as|named|to] <name>")
      return
    }
    Some(info) => {
      let desc = get_command_description(info.wraps_cmd)
      let final_desc = desc.replace(old="\"", new="'")
      let script = build_update_script(info, final_desc)
      let result = run_shell(script, ".")
      if result.stdout.length() > 0 {
        println(result.stdout.trim())
      }
      if result.stderr.length() > 0 {
        println(result.stderr.trim())
      }
    }
  }
}

fn print_usage() -> Unit {
  println("\{program_name} - fish wrapper helper")
  println("")
  println("Usage:")
  println("  \{program_name} wrap <command...> [for|as|named|to] <name>")
  println("  \{program_name} <command...> [for|as|named|to] <name>")
  println("  \{program_name} agent <fish request...>")
  println("  \{program_name} -h | --help")
}

fn args_slice(args : Array[String], start : Int) -> Array[String] {
  let out : Array[String] = []
  let mut i = start
  while i < args.length() {
    out.push(args[i])
    i += 1
  }
  out
}

fn join_args(args : Array[String], start : Int) -> String {
  let out : Array[String] = []
  let mut i = start
  while i < args.length() {
    out.push(args[i])
    i += 1
  }
  out.join(" ")
}

fn parse_wrap(tokens : Array[String]) -> ParsedWrap? {
  if tokens.length() == 0 {
    return None
  }

  let mut start = 0
  if tokens[0] == "wrap" {
    start = 1
  }
  if start >= tokens.length() {
    return None
  }

  let mut marker_idx = -1
  let mut i = start
  while i < tokens.length() {
    let tok = tokens[i]
    if tok == "for" || tok == "as" || tok == "named" || tok == "to" || tok == "with" {
      marker_idx = i
      break
    }
    i += 1
  }

  let cmd_tokens : Array[String] = []
  if marker_idx < 0 {
    i = start
    while i < tokens.length() {
      cmd_tokens.push(tokens[i])
      i += 1
    }
  } else {
    i = start
    while i < marker_idx {
      cmd_tokens.push(tokens[i])
      i += 1
    }
  }

  if cmd_tokens.length() == 0 {
    return None
  }

  let cmd = cmd_tokens.join(" ")
  let wraps_cmd = cmd_tokens[0]

  let mut wrapper = "w"
  if marker_idx >= 0 && marker_idx + 1 < tokens.length() {
    wrapper = tokens[marker_idx + 1]
  }

  Some(ParsedWrap::{ cmd, wraps_cmd, wrapper })
}

fn build_update_script(info : ParsedWrap, desc : String) -> String {
  let wrap = escape_double_quotes(info.wrapper)
  let cmd = escape_double_quotes(info.cmd)
  let wraps_cmd = escape_double_quotes(info.wraps_cmd)
  let desc_q = escape_double_quotes(desc)

  let script =
    "WRAP=\"" + wrap + "\" " +
    "CMD=\"" + cmd + "\" " +
    "WRAPS=\"" + wraps_cmd + "\" " +
    "DESC=\"" + desc_q + "\" " +
    "python - <<'PY'\n" +
    "import os, re, pathlib\n" +
    "wrap = os.environ.get('WRAP', 'w')\n" +
    "cmd = os.environ.get('CMD', '')\n" +
    "wraps_cmd = os.environ.get('WRAPS', cmd.split(' ')[0] if cmd else '')\n" +
    "desc = os.environ.get('DESC', f\"Wrap {cmd}\")\n" +
    "path = pathlib.Path('" + target_file + "')\n" +
    "content = path.read_text() if path.exists() else ''\n" +
    "pattern = re.compile(r'^function ' + re.escape(wrap) + r' .*?^end\\n', re.M | re.S)\n" +
    "content = pattern.sub('', content)\n" +
    "func = f\"\"\"function {wrap} --wraps={wraps_cmd} --description \\\"{desc}\\\"\\n\"\"\"\n" +
    "func += f\"    {cmd} $argv\\n\"\n" +
    "func += \"end\\n\"\n" +
    "func += f\"complete -c {wrap} -w {wraps_cmd}\\n\"\n" +
    "if content and not content.endswith('\\n'):\n" +
    "    content += '\\n'\n" +
    "content += func\n" +
    "path.parent.mkdir(parents=True, exist_ok=True)\n" +
    "path.write_text(content)\n" +
    "print(f\"Wrote {wrap} to {path}\")\n" +
    "print(f\"Run: source {path}\")\n" +
    "PY\n" +
    "if test -f /Users/nikiv/.config/fish/functions/" + info.wrapper + ".fish; then " +
    "rm -f /Users/nikiv/.config/fish/functions/" + info.wrapper + ".fish; " +
    "echo 'Removed /Users/nikiv/.config/fish/functions/" + info.wrapper + ".fish'; " +
    "fi\n"
  script
}

async fn get_command_description(cmd : String) -> String raise {
  let result = run_shell(cmd + " --help 2>/dev/null", ".")
  if result.exit_code != 0 || result.stdout.length() == 0 {
    return "Wrap " + cmd
  }
  for line_view in result.stdout.split("\n") {
    let line = trim_whitespace(line_view.to_string())
    if line.length() == 0 {
      continue
    }
    if line.to_lower().contains(cmd.to_lower()) && line.contains(" - ") {
      return line
    }
  }
  "Wrap " + cmd
}

fn escape_double_quotes(value : String) -> String {
  value.replace(old="\\", new="\\\\").replace(old="\"", new="\\\"")
}

fn trim_whitespace(s : String) -> String {
  s.trim(chars=" \n\t\r").to_string()
}

struct CmdResult {
  exit_code : Int
  stdout : String
  stderr : String
}

async fn run_shell(command : String, cwd : String) -> CmdResult raise {
  let (exit_code, stdout_data, stderr_data) = @process.collect_output(
    "sh",
    ["-c", command],
    cwd~,
  )
  CmdResult::{
    exit_code,
    stdout: stdout_data.text(),
    stderr: stderr_data.text(),
  }
}

enum FishyAction {
  Wrap(String, String, String?)
  Set(String, String, Array[String])
  Function(String, String, String?)
}

async fn infer_action(prompt : String) -> FishyAction? raise {
  let (model_name, port) = resolve_model_port()
  let system_prompt =
    "You convert fish shell requests into JSON. Output ONLY JSON. " +
    "No markdown, no backticks, no extra text, no explanations. " +
    "Schema: {\"action\":\"wrap|set|function|unknown\", " +
    "\"name\":\"\", \"command\":\"\", \"args\":[], " +
    "\"flags\":\"\", \"var\":\"\", \"values\":[], " +
    "\"body\":\"\", \"description\":\"\"}. " +
    "Use empty strings or empty arrays when a field is not needed."
  let response = prompt_local_model(model_name, port, system_prompt, prompt)
  let parsed = extract_json_object(response)
  match parsed {
    None => None
    Some(json) => parse_action_json(json)
  }
}

fn parse_action_json(json : Json) -> FishyAction? {
  guard json is Object(obj) else { return None }
  let action = json_string(obj, "action").unwrap_or("")
  let name = json_string(obj, "name").unwrap_or("w")
  let desc = json_string(obj, "description")
  let command = json_string(obj, "command").unwrap_or("")
  let args = json_string_array(obj, "args")
  let flags = json_string(obj, "flags").unwrap_or("")
  let var_name = json_string(obj, "var").unwrap_or("")
  let values = json_string_array(obj, "values")
  let body = json_string(obj, "body").unwrap_or("")

  match action {
    "wrap" => {
      let cmd = if args.length() > 0 {
        command + " " + args.join(" ")
      } else {
        command
      }
      if cmd.length() == 0 {
        None
      } else {
        Some(FishyAction::Wrap(name, cmd, desc))
      }
    }
    "set" => {
      if flags.length() == 0 || var_name.length() == 0 {
        None
      } else {
        Some(FishyAction::Set(flags, var_name, values))
      }
    }
    "function" => {
      let content = if body.length() > 0 { body } else { command }
      if content.length() == 0 {
        None
      } else {
        Some(FishyAction::Function(name, content, desc))
      }
    }
    _ => None
  }
}

fn build_action_script(action : FishyAction) -> String {
  match action {
    Wrap(name, command, description) => {
      let wraps_cmd = first_token(command)
      let desc = description.unwrap_or("Wrap " + wraps_cmd)
      let info = ParsedWrap::{ cmd: command, wraps_cmd, wrapper: name }
      build_update_script(info, desc)
    }
    Set(flags, var_name, values) => build_set_script(flags, var_name, values)
    Function(name, body, description) => build_function_script(name, body, description)
  }
}

fn build_set_script(flags : String, var_name : String, values : Array[String]) -> String {
  let config_path = "/Users/nikiv/config/fish/config.fish"
  let marker = "# hive:set " + var_name
  let end_marker = "# hive:end " + var_name
  let mut vals = ""
  let mut i = 0
  while i < values.length() {
    if i > 0 {
      vals = vals + " "
    }
    vals = vals + values[i]
    i += 1
  }
  let mut block = ""
  if flags.contains("a") && values.length() > 0 {
    block = "for __val in " + vals + "\n" +
      "    if not contains -- $__val $" + var_name + "\n" +
      "        set " + flags + " " + var_name + " $__val\n" +
      "    end\n" +
      "end\n"
  } else {
    block = "set " + flags + " " + var_name + (if vals.length() > 0 { " " + vals } else { "" }) + "\n"
  }

  "VAR=\"" + escape_double_quotes(var_name) + "\" " +
  "MARKER=\"" + escape_double_quotes(marker) + "\" " +
  "END_MARKER=\"" + escape_double_quotes(end_marker) + "\" " +
  "BLOCK=\"" + escape_double_quotes(block) + "\" " +
  "python - <<'PY'\n" +
  "import os, re, pathlib\n" +
  "var = os.environ['VAR']\n" +
  "marker = os.environ['MARKER']\n" +
  "end_marker = os.environ['END_MARKER']\n" +
  "block = os.environ['BLOCK']\n" +
  "path = pathlib.Path('" + config_path + "')\n" +
  "content = path.read_text() if path.exists() else ''\n" +
  "pattern = re.compile(r'^' + re.escape(marker) + r'.*?^' + re.escape(end_marker) + r'\\n', re.M | re.S)\n" +
  "replacement = marker + \"\\n\" + block + end_marker + \"\\n\"\n" +
  "if pattern.search(content):\n" +
  "    content = pattern.sub(replacement, content)\n" +
  "else:\n" +
  "    m = re.search(r'^source .*fn\\.fish.*\\nsource .*i\\.fish.*\\n', content, re.M)\n" +
  "    if m:\n" +
  "        insert_at = m.end()\n" +
  "        content = content[:insert_at] + \"\\n\" + replacement + content[insert_at:]\n" +
  "    else:\n" +
  "        content = replacement + \"\\n\" + content\n" +
  "path.parent.mkdir(parents=True, exist_ok=True)\n" +
  "path.write_text(content)\n" +
  "print(f\"Updated {path}\")\n" +
  "print(f\"Run: source {path}\")\n" +
  "PY\n"
}

fn build_function_script(name : String, body : String, description : String?) -> String {
  let desc = description.unwrap_or("Custom fish function")
  let lines : Array[String] = []
  for line_view in body.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    lines.push("    " + line)
  }
  let func_body = lines.join("\n") + (if lines.length() > 0 { "\n" } else { "" })

  "NAME=\"" + escape_double_quotes(name) + "\" " +
  "DESC=\"" + escape_double_quotes(desc) + "\" " +
  "BODY=\"" + escape_double_quotes(func_body) + "\" " +
  "python - <<'PY'\n" +
  "import os, re, pathlib\n" +
  "name = os.environ['NAME']\n" +
  "desc = os.environ['DESC']\n" +
  "body = os.environ['BODY']\n" +
  "path = pathlib.Path('" + target_file + "')\n" +
  "content = path.read_text() if path.exists() else ''\n" +
  "pattern = re.compile(r'^function ' + re.escape(name) + r' .*?^end\\n', re.M | re.S)\n" +
  "content = pattern.sub('', content)\n" +
  "func = f\"\"\"function {name} --description \\\"{desc}\\\"\\n\"\"\"\n" +
  "func += body\n" +
  "func += \"end\\n\"\n" +
  "if content and not content.endswith('\\n'):\n" +
  "    content += '\\n'\n" +
  "content += func\n" +
  "path.parent.mkdir(parents=True, exist_ok=True)\n" +
  "path.write_text(content)\n" +
  "print(f\"Wrote {name} to {path}\")\n" +
  "print(f\"Run: source {path}\")\n" +
  "PY\n" +
  "if test -f /Users/nikiv/.config/fish/functions/" + name + ".fish; then " +
  "rm -f /Users/nikiv/.config/fish/functions/" + name + ".fish; " +
  "echo 'Removed /Users/nikiv/.config/fish/functions/" + name + ".fish'; " +
  "fi\n"
}

fn resolve_model_port() -> (String, Int) {
  let mut model = ""
  match @sys.get_env_var("FISHY_LMSTUDIO_MODEL") {
    Some(value) => model = value
    None => ()
  }
  if model.length() == 0 {
    match @sys.get_env_var("LM_STUDIO_MODEL") {
      Some(value) => model = value
      None => ()
    }
  }
  if model.length() == 0 {
    model = default_lm_model
  }

  let mut port = -1
  match @sys.get_env_var("FISHY_LMSTUDIO_PORT") {
    Some(value) => {
      port = try { @strconv.parse_int(value) } catch { _ => -1 }
    }
    None => ()
  }
  if port <= 0 {
    match @sys.get_env_var("LM_STUDIO_PORT") {
      Some(value) => {
        port = try { @strconv.parse_int(value) } catch { _ => -1 }
      }
      None => ()
    }
  }
  if port <= 0 {
    port = default_lm_port
  }
  (model, port)
}

async fn prompt_local_model(
  model_name : String,
  port : Int,
  system_prompt : String,
  user_prompt : String,
) -> String raise {
  let url = "http://localhost:\{port}/v1/chat/completions"
  let body : Json = {
    "model": model_name,
    "messages": Json::array([
      Json::object({ "role": "system", "content": system_prompt }),
      Json::object({ "role": "user", "content": user_prompt }),
    ]),
    "temperature": 0.1,
    "max_tokens": 512,
  }
  let headers = {
    "Content-Type": "application/json",
  }
  let (response, data) = @http.post(url, body, headers~)
  if response.code < 200 || response.code > 299 {
    return ""
  }
  let text_body = data.text()
  extract_chat_content(text_body)
}

fn extract_chat_content(text_body : String) -> String {
  let parsed = try { @json.parse(text_body) } catch { _ => return "" }
  match parsed {
    Object(obj) => {
      match obj.get("choices") {
        Some(Array(choices)) => {
          if choices.length() == 0 {
            return ""
          }
          match choices[0] {
            Object(choice) => {
              match choice.get("message") {
                Some(Object(msg)) =>
                  match msg.get("content") {
                    Some(String(content)) => content.trim().to_string()
                    _ => ""
                  }
                _ => ""
              }
            }
            _ => ""
          }
        }
        _ => ""
      }
    }
    _ => ""
  }
}

fn extract_json_object(text : String) -> Json? {
  let trimmed = trim_whitespace(text)
  match try_parse_json(trimmed) {
    Some(json) =>
      match json {
        Object(_) => return Some(json)
        _ => ()
      }
    None => ()
  }
  let objects = collect_json_objects(trimmed)
  let mut i = objects.length() - 1
  while i >= 0 {
    let slice = objects[i]
    match try_parse_json(slice) {
      Some(json) =>
        match json {
          Object(_) => return Some(json)
          _ => ()
        }
      None => ()
    }
    if i == 0 {
      break
    }
    i -= 1
  }
  None
}

fn try_parse_json(text : String) -> Json? {
  try {
    let parsed = @json.parse(text)
    Some(parsed)
  } catch {
    _ => None
  }
}

fn json_string(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

fn json_string_array(obj : Map[String, Json], key : String) -> Array[String] {
  let out : Array[String] = []
  match obj.get(key) {
    Some(Array(values)) => {
      for item in values {
        match item {
          String(value) => out.push(value)
          _ => ()
        }
      }
    }
    _ => ()
  }
  out
}

fn index_of_char(text : String, ch : Char) -> Int {
  let mut i = 0
  for c in text {
    if c == ch {
      return i
    }
    i += 1
  }
  -1
}

fn last_index_of_char(text : String, ch : Char) -> Int {
  let mut idx = -1
  let mut i = 0
  for c in text {
    if c == ch {
      idx = i
    }
    i += 1
  }
  idx
}

fn first_token(text : String) -> String {
  let buf = StringBuilder::new()
  for c in text {
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      break
    }
    buf.write_char(c)
  }
  buf.to_string()
}

fn substring(text : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  for c in text {
    if i >= start && i < end {
      buf.write_char(c)
    }
    i += 1
  }
  buf.to_string()
}

fn collect_json_objects(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut depth = 0
  let mut start = -1
  let mut i = 0
  for c in text {
    if c == '{' {
      if depth == 0 {
        start = i
      }
      depth += 1
    } else if c == '}' {
      if depth > 0 {
        depth -= 1
        if depth == 0 && start >= 0 {
          out.push(substring(text, start, i + 1))
          start = -1
        }
      }
    }
    i += 1
  }
  out
}
