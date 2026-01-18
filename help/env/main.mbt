///|
/// env-help - Flow env helper CLI (global-only)
///
/// Usage:
///   env-help help
///   env-help save [service] <values...>
///   env-help save --env <name> [service] <values...>
///   env-help list [--env <name>]
///
/// Examples:
///   env-help save aws Access Key ID: AKIA... Secret Access Key: ... Region: eu-central-1
///   env-help save --env staging generic API_KEY=sk-123
///   env-help list --env production

let program_name = "env-help"

async fn main raise {
  let args = @sys.get_cli_args()
  if args.length() <= 1 {
    print_usage()
    return
  }

  let command = args[1]
  if command == "help" || command == "--help" || command == "-h" {
    print_usage()
    return
  }

  if command == "list" {
    list_command(args, 2)
    return
  }

  if command == "save" || command == "set" {
    save_command(args, 2)
    return
  }

  // Default: treat first arg as service
  save_command(args, 1)
}

fn print_usage() -> Unit {
  println("\{program_name} - store global env vars locally via Flow")
  println("")
  println("Usage:")
  println("  env-help save [service] <values...>")
  println("  env-help save --env <name> [service] <values...>")
  println("  env-help list [--env <name>]")
  println("")
  println("Notes:")
  println("  - Uses FLOW_ENV_BACKEND=local")
  println("  - Stores in global (personal) scope only")
  println("  - Values are never printed")
  println("")
  println("Examples:")
  println("  env-help save aws Access Key ID: AKIA... Secret Access Key: ... Region: eu-central-1")
  println("  env-help save generic API_KEY=sk-123")
  println("  env-help list --env production")
}

async fn save_command(args : Array[String], start : Int) -> Unit raise {
  let cwd = get_cwd()
  let parsed = parse_env_args(args, start, cwd)
  if parsed.service.length() == 0 {
    println("Usage: env-help save <service> <values...>")
    return
  }

  let text = parsed.payload
  if text.length() == 0 {
    println("No values provided.")
    return
  }

  let items = parse_env_items(parsed.service, text)
  if items.length() == 0 {
    println("No env values found.")
    return
  }

  let f_check = run_shell("command -v f >/dev/null 2>&1", cwd)
  if f_check.exit_code != 0 {
    println("Flow CLI not found. Install and run `f env` first.")
    return
  }

  for item in items {
    let result = run_flow_set(item.key, item.value)
    if result.exit_code == 0 {
      println("set \{item.key} (\{mask_value(item.value)})")
    } else {
      println("failed \{item.key}")
      if result.stderr.length() > 0 {
        println(result.stderr.trim())
      }
    }
  }
}

async fn list_command(args : Array[String], start : Int) -> Unit raise {
  let cwd = get_cwd()
  let parsed = parse_env_args(args, start, cwd)
  let result = run_flow_list(parsed.env_name)
  if result.stdout.length() > 0 {
    println(result.stdout.trim())
  }
  if result.stderr.length() > 0 {
    println(result.stderr.trim())
  }
}

struct EnvArgs {
  service : String
  payload : String
  env_name : String
}

fn parse_env_args(args : Array[String], start : Int, default_root : String) -> EnvArgs {
  let mut service = ""
  let mut payload = ""
  let mut env_name = "production"

  let parts : Array[String] = []
  let mut i = start
  while i < args.length() {
    let arg = args[i]
    if arg == "--env" || arg == "-e" {
      i += 1
      if i < args.length() {
        env_name = args[i]
      }
    } else if service.length() == 0 {
      service = arg
    } else {
      parts.push(arg)
    }
    i += 1
  }

  if parts.length() > 0 {
    payload = parts.join(" ")
  }

  let _ = default_root
  if service.length() > 0 && payload.length() == 0 && service.contains("=") {
    payload = service
    service = "generic"
  }
  EnvArgs::{ service, payload, env_name }
}

struct EnvItem {
  key : String
  value : String
}

fn parse_env_items(service : String, text : String) -> Array[EnvItem] {
  let lower_service = service.to_lower()
  if lower_service == "aws" || lower_service == "s3" {
    let labels : Array[(String, String)] = [
      ("access key id", "AWS_ACCESS_KEY_ID"),
      ("secret access key", "AWS_SECRET_ACCESS_KEY"),
      ("region", "AWS_REGION"),
    ]
    let items = parse_label_pairs(text, labels)
    if items.length() > 0 {
      return items
    }
  }

  let items = parse_key_value_pairs(text)
  if items.length() > 0 {
    return items
  }

  []
}

fn parse_label_pairs(text : String, labels : Array[(String, String)]) -> Array[EnvItem] {
  let lower = text.to_lower()
  let hits : Array[(Int, Int, String)] = []

  for label_pair in labels {
    let label = label_pair.0
    let key = label_pair.1
    let idx = index_of(lower, label)
    if idx >= 0 {
      hits.push((idx, label.length(), key))
    }
  }

  if hits.length() == 0 {
    return []
  }

  let ordered = sort_hits(hits)
  let items : Array[EnvItem] = []
  let mut i = 0
  while i < ordered.length() {
    let (start_idx, label_len, key) = ordered[i]
    let next_idx = if i + 1 < ordered.length() {
      ordered[i + 1].0
    } else {
      text.length()
    }
    let mut value_start = start_idx + label_len
    let colon_idx = find_char_in_range(text, ':', value_start, next_idx)
    if colon_idx >= 0 {
      value_start = colon_idx + 1
    }
    while value_start < text.length() {
      let ch = char_at(text, value_start)
      if ch == ' ' || ch == '\t' {
        value_start += 1
      } else {
        break
      }
    }
    let value = trim_whitespace(substring(text, value_start, next_idx))
    if value.length() > 0 {
      items.push(EnvItem::{ key, value })
    }
    i += 1
  }
  items
}

fn parse_key_value_pairs(text : String) -> Array[EnvItem] {
  let items : Array[EnvItem] = []
  for line_view in text.split("\n") {
    let line = trim_whitespace(line_view.to_string())
    if line.length() == 0 {
      continue
    }
    for part_view in line.split(" ") {
      let part = trim_whitespace(part_view.to_string())
      if part.length() == 0 {
        continue
      }
      let eq = index_of(part, "=")
      if eq > 0 && eq < part.length() - 1 {
        let key = substring(part, 0, eq)
        let value = substring(part, eq + 1, part.length())
        if key.length() > 0 && value.length() > 0 {
          items.push(EnvItem::{ key, value })
        }
      }
    }
  }
  items
}

fn sort_hits(hits : Array[(Int, Int, String)]) -> Array[(Int, Int, String)] {
  let sorted : Array[(Int, Int, String)] = []
  let used : Array[Bool] = []
  let mut i = 0
  while i < hits.length() {
    used.push(false)
    i += 1
  }

  let mut count = 0
  while count < hits.length() {
    let mut min_index = -1
    let mut j = 0
    while j < hits.length() {
      if !used[j] {
        if min_index < 0 || hits[j].0 < hits[min_index].0 {
          min_index = j
        }
      }
      j += 1
    }
    if min_index < 0 {
      break
    }
    used[min_index] = true
    sorted.push(hits[min_index])
    count += 1
  }
  sorted
}

async fn run_flow_set(key : String, value : String) -> CmdResult raise {
  let args : Array[String] = []
  args.push("env")
  args.push("set")
  args.push("\{key}=\{value}")
  run_flow_cmd(args)
}

async fn run_flow_list(env_name : String) -> CmdResult raise {
  let args : Array[String] = []
  args.push("env")
  args.push("list")
  if env_name.length() > 0 {
    args.push("-e")
    args.push(env_name)
  }
  run_flow_cmd(args)
}

async fn run_flow_cmd(args : Array[String]) -> CmdResult raise {
  let command = "FLOW_ENV_BACKEND=local f"
  let cwd = get_cwd()
  run_exec(command, args, cwd)
}

fn mask_value(value : String) -> String {
  let trimmed = trim_whitespace(value)
  if trimmed.length() <= 4 {
    "****"
  } else if trimmed.length() <= 8 {
    substring(trimmed, 0, 2) + "****"
  } else {
    substring(trimmed, 0, 4) + "..." + substring(trimmed, trimmed.length() - 2, trimmed.length())
  }
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
  CmdResult::{ exit_code, stdout: stdout_data.text(), stderr: stderr_data.text() }
}

async fn run_exec(command : String, args : Array[String], cwd : String) -> CmdResult raise {
  let (exit_code, stdout_data, stderr_data) = @process.collect_output(
    "sh",
    ["-c", command + " " + shell_join(args)],
    cwd~,
  )
  CmdResult::{ exit_code, stdout: stdout_data.text(), stderr: stderr_data.text() }
}

fn shell_join(parts : Array[String]) -> String {
  let escaped : Array[String] = []
  for part in parts {
    escaped.push("'" + escape_single_quotes(part) + "'")
  }
  escaped.join(" ")
}

fn escape_single_quotes(s : String) -> String {
  s.replace(old="'", new="'\\''")
}

fn get_cwd() -> String {
  match @sys.get_env_var("PWD") {
    Some(path) => path
    None => "."
  }
}

fn trim_whitespace(s : String) -> String {
  s.trim(chars=" \n\t\r").to_string()
}


fn substring(s : String, start : Int, end : Int) -> String {
  let result : Array[Char] = []
  let mut i = 0
  for c in s {
    if i >= start && i < end {
      result.push(c)
    }
    i += 1
  }
  String::from_array(result)
}

fn char_at(s : String, index : Int) -> Char {
  let mut i = 0
  for c in s {
    if i == index {
      return c
    }
    i += 1
  }
  Int::unsafe_to_char(0)
}

fn find_char_in_range(s : String, ch : Char, start : Int, end : Int) -> Int {
  let mut i = 0
  for c in s {
    if i >= start && i < end {
      if c == ch {
        return i
      }
    }
    i += 1
  }
  -1
}

fn index_of(haystack : String, needle : String) -> Int {
  if needle.length() == 0 {
    return 0
  }
  let hay : Array[Char] = []
  let nee : Array[Char] = []
  for c in haystack {
    hay.push(c)
  }
  for c in needle {
    nee.push(c)
  }
  let mut i = 0
  while i + nee.length() <= hay.length() {
    let mut matched = true
    let mut j = 0
    while j < nee.length() {
      if hay[i + j] != nee[j] {
        matched = false
        break
      }
      j += 1
    }
    if matched {
      return i
    }
    i += 1
  }
  -1
}
