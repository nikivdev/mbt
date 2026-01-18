///|
/// zed-help - Zed helper CLI
///
/// Usage:
///   zed-help                  - Fuzzy-pick a folder to include in Zed search
///   zed-help include [path]   - Add folder to .zed/settings.json inclusions
///   zed-help list             - List current file_scan_inclusions
///   zed-help open [path]      - Open path in Zed (default: .)
///   zed-help help             - Show help

let program_name = "zed-help"

async fn main {
  let args = @sys.get_cli_args()
  if args.length() <= 1 {
    include_command(args, 1)
    return
  }

  let command = args[1]
  if command == "help" || command == "--help" || command == "-h" {
    print_usage()
    return
  }

  if command == "include" || command == "add" {
    include_command(args, 2)
    return
  }

  if command == "list" {
    list_command(args, 2)
    return
  }

  if command == "open" {
    open_command(args, 2)
    return
  }

  passthrough_to_zed(args, 1)
}

fn print_usage() -> Unit {
  println("\{program_name} - Zed project helper")
  println("")
  println("Usage:")
  println("  \{program_name}                  Fuzzy-pick a folder to include in search")
  println("  \{program_name} include [path]   Add folder to .zed/settings.json")
  println("  \{program_name} list             List current file_scan_inclusions")
  println("  \{program_name} open [path]      Open path in Zed (default: .)")
  println("  \{program_name} help             Show help")
  println("")
  println("Options:")
  println("  -r, --root <path>         Project root (defaults to cwd)")
  println("")
  println("Examples:")
  println("  \{program_name} include stream")
  println("  \{program_name} include --root ~/code/lang/cpp stream")
  println("  \{program_name} list --root ~/code/lang/cpp")
}

async fn include_command(args : Array[String], start : Int) -> Unit {
  let cwd = get_cwd()
  let (root_raw, path_opt) = parse_root_and_path(args, start, cwd)
  let root = normalize_root(root_raw, cwd)

  let selected_path = match path_opt {
    Some(path) => Some(path)
    None => fuzzy_pick_directory(root)
  }

  match selected_path {
    None => return
    Some(path) => {
      let inclusion = match normalize_include_path(path, root) {
        Some(value) => value
        None => {
          println("Invalid path: \{path}")
          return
        }
      }

      let settings_path = settings_file_path(root)
      guard ensure_settings_dir(root) else {
        println("Failed to create .zed directory in \{root}")
        return
      }

      let settings_json = match read_settings_json(settings_path) {
        Ok(json) => json
        Err(err) => {
          println("Failed to read settings: \{err}")
          return
        }
      }

      let updated = match add_inclusion(settings_json, inclusion) {
        Ok(json) => json
        Err(err) => {
          println(err)
          return
        }
      }

      if write_settings_json(settings_path, updated) {
        println("Added: \{inclusion}")
        println("Updated: \{settings_path}")
        println("Restart Zed or reopen the project to refresh search results.")
      } else {
        println("Failed to write settings: \{settings_path}")
      }
    }
  }
}

fn list_command(args : Array[String], start : Int) -> Unit {
  let cwd = get_cwd()
  let root_raw = parse_root(args, start, cwd)
  let root = normalize_root(root_raw, cwd)
  let settings_path = settings_file_path(root)
  let settings_json = match read_settings_json(settings_path) {
    Ok(json) => json
    Err(err) => {
      println("Failed to read settings: \{err}")
      return
    }
  }

  let inclusions = match read_inclusions(settings_json) {
    Ok(values) => values
    Err(err) => {
      println(err)
      return
    }
  }

  if inclusions.length() == 0 {
    println("No file_scan_inclusions set.")
    return
  }

  println("file_scan_inclusions:")
  for item in inclusions {
    println("  \{item}")
  }
}

async fn open_command(args : Array[String], start : Int) -> Unit {
  let cwd = get_cwd()
  let (root_raw, path_opt) = parse_root_and_path(args, start, cwd)
  let root = normalize_root(root_raw, cwd)
  let path = match path_opt {
    Some(value) => value
    None => "."
  }

  let open_args : Array[String] = []
  if path.length() == 0 {
    open_args.push(".")
  } else {
    open_args.push(path)
  }

  let result = run_exec("zed", open_args, root)
  if result.exit_code != 0 {
    println("Failed to launch Zed: \{result.stderr}")
  }
}

async fn passthrough_to_zed(args : Array[String], start : Int) -> Unit {
  let cwd = get_cwd()
  let passthrough : Array[String] = []
  let mut i = start
  while i < args.length() {
    passthrough.push(args[i])
    i += 1
  }
  let result = run_exec("zed", passthrough, cwd)
  if result.exit_code != 0 && result.stderr.length() > 0 {
    println(result.stderr)
  }
}

fn parse_root_and_path(
  args : Array[String],
  start : Int,
  default_root : String,
) -> (String, String?) {
  let mut root = default_root
  let mut path : String? = None
  let mut i = start
  while i < args.length() {
    let arg = args[i]
    if arg == "--root" || arg == "-r" {
      i += 1
      if i < args.length() {
        root = args[i]
      }
    } else if arg == "--path" || arg == "-p" {
      i += 1
      if i < args.length() {
        path = Some(args[i])
      }
    } else if path is None {
      path = Some(arg)
    }
    i += 1
  }
  (root, path)
}

fn parse_root(args : Array[String], start : Int, default_root : String) -> String {
  let mut root = default_root
  let mut i = start
  while i < args.length() {
    let arg = args[i]
    if arg == "--root" || arg == "-r" {
      i += 1
      if i < args.length() {
        root = args[i]
      }
    } else if !arg.has_prefix("-") {
      root = arg
    }
    i += 1
  }
  root
}

fn normalize_root(root : String, cwd : String) -> String {
  let expanded = expand_path(root)
  let absolute = if expanded.has_prefix("/") {
    expanded
  } else {
    join_paths(cwd, expanded)
  }
  strip_trailing_slash(absolute)
}

fn settings_file_path(root : String) -> String {
  join_paths(join_paths(root, ".zed"), "settings.json")
}

fn ensure_settings_dir(root : String) -> Bool {
  let dir = join_paths(root, ".zed")
  let exists = try { @fs.is_dir(dir) } catch { _ => false }
  if exists {
    return true
  }
  try {
    @fs.create_dir(dir)
    true
  } catch {
    _ => false
  }
}

fn read_settings_json(path : String) -> Result[Json, String] {
  let exists = @fs.path_exists(path)
  if !exists {
    return Ok(Json::object({}))
  }
  try {
    let content = @fs.read_file_to_string(path)
    Ok(@json.parse(content))
  } catch {
    e => Err(e.to_string())
  }
}

fn write_settings_json(path : String, json : Json) -> Bool {
  let content = json.stringify(indent=2) + "\n"
  try {
    @fs.write_string_to_file(path, content)
    true
  } catch {
    _ => false
  }
}

fn read_inclusions(settings : Json) -> Result[Array[String], String] {
  match settings {
    Object(obj) => {
      match obj.get("file_scan_inclusions") {
        Some(Array(arr)) => {
          let result : Array[String] = []
          for item in arr {
            match item {
              String(value) => result.push(value)
              _ => ()
            }
          }
          Ok(result)
        }
        Some(_) => Err("file_scan_inclusions is not an array")
        None => Ok([])
      }
    }
    _ => Err("settings.json root must be an object")
  }
}

fn add_inclusion(settings : Json, inclusion : String) -> Result[Json, String] {
  match settings {
    Object(obj) => {
      let inclusions : Array[Json] = []
      match obj.get("file_scan_inclusions") {
        Some(Array(arr)) =>
          for item in arr {
            inclusions.push(item)
          }
        Some(_) => return Err("file_scan_inclusions is not an array")
        None => ()
      }

      if !json_array_contains_string(inclusions, inclusion) {
        inclusions.push(Json::string(inclusion))
      }

      obj["file_scan_inclusions"] = Json::array(inclusions)
      Ok(Json::object(obj))
    }
    _ => Err("settings.json root must be an object")
  }
}

fn json_array_contains_string(arr : Array[Json], value : String) -> Bool {
  for item in arr {
    match item {
      String(text) => if text == value { return true }
      _ => ()
    }
  }
  false
}

fn normalize_include_path(raw : String, root : String) -> String? {
  let trimmed = trim_whitespace(raw)
  if trimmed.length() == 0 {
    return None
  }

  let expanded = expand_path(trimmed)
  let mut path = expanded

  if path.has_prefix(root + "/") {
    path = string_from(path, root.length() + 1)
  } else if path == root {
    return None
  } else if path.has_prefix("/") {
    return None
  }

  if path.has_prefix("./") {
    path = string_from(path, 2)
  }

  if path.has_suffix("/") && path.length() > 1 {
    path = string_until(path, path.length() - 1)
  }

  if path.length() == 0 {
    return None
  }

  if path.has_suffix("/**") {
    Some(path)
  } else {
    Some(path + "/**")
  }
}

async fn fuzzy_pick_directory(root : String) -> String? {
  let fzf_check = run_shell("command -v fzf >/dev/null 2>&1", root)
  if fzf_check.exit_code != 0 {
    println("fzf not found - install it or pass a path explicitly")
    return None
  }

  let find_cmd =
    "find . " +
    "\\( -path '*/.*' -o -path '*/_build' -o -path '*/target' -o -path '*/node_modules' \\) -prune -o " +
    "-type d -print | sed 's|^\\./||' | grep -v '^\\.$' | " +
    "fzf --prompt='zed-help> ' --height=40% --reverse"

  let result = run_shell(find_cmd, root)
  if result.exit_code != 0 {
    return None
  }
  let selected = trim_whitespace(result.stdout)
  if selected.length() == 0 {
    None
  } else {
    Some(selected)
  }
}

struct CmdResult {
  exit_code : Int
  stdout : String
  stderr : String
}

async fn run_shell(command : String, cwd : String) -> CmdResult {
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

async fn run_exec(program : String, args : Array[String], cwd : String) -> CmdResult {
  let (exit_code, stdout_data, stderr_data) = @process.collect_output(
    program,
    args,
    cwd~,
  )
  CmdResult::{
    exit_code,
    stdout: stdout_data.text(),
    stderr: stderr_data.text(),
  }
}

fn get_cwd() -> String {
  match @sys.get_env_var("PWD") {
    Some(path) => path
    None => "."
  }
}

fn expand_path(path : String) -> String {
  if path.has_prefix("~") {
    match @sys.get_env_var("HOME") {
      Some(home) => home + string_from(path, 1)
      None => path
    }
  } else {
    path
  }
}

fn join_paths(base : String, part : String) -> String {
  if base.has_suffix("/") {
    base + part
  } else {
    base + "/" + part
  }
}

fn strip_trailing_slash(path : String) -> String {
  if path.length() > 1 && path.has_suffix("/") {
    string_until(path, path.length() - 1)
  } else {
    path
  }
}

fn trim_whitespace(s : String) -> String {
  s.trim(chars=" \n\t\r").to_string()
}

fn string_from(s : String, start : Int) -> String {
  let result : Array[Char] = []
  let mut i = 0
  for c in s {
    if i >= start {
      result.push(c)
    }
    i += 1
  }
  String::from_array(result)
}

fn string_until(s : String, end : Int) -> String {
  let result : Array[Char] = []
  let mut i = 0
  for c in s {
    if i >= end {
      break
    }
    result.push(c)
    i += 1
  }
  String::from_array(result)
}
