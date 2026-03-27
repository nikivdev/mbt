///|
/// Shell CLI - Manage shell command registry and wrappers

async fn main {
  let args = @sys.get_cli_args()

  if args.length() <= 1 {
    print_help()
    return
  }

  let command = args[1]

  match command {
    "generate" | "gen" => generate_wrappers()
    "list" | "ls" => list_commands()
    "install" => install_wrappers()
    "context" => show_context()
    "add" => {
      if args.length() > 2 {
        add_command(args[2])
      } else {
        println("Error: specify command name to add")
      }
    }
    "trace" => show_traces()
    "--help" | "-h" | "help" => print_help()
    _ => {
      println("Unknown command: " + command)
      print_help()
    }
  }
}

fn print_help() -> Unit {
  println("shell - Shell command registry and tracing")
  println("")
  println("USAGE:")
  println("  shell <command>")
  println("")
  println("COMMANDS:")
  println("  generate    Generate fish wrappers for all registered commands")
  println("  list        List all registered commands")
  println("  install     Install wrappers to ~/.config/fish/conf.d/")
  println("  context     Show current AI context (for debugging)")
  println("  add <cmd>   Add a new command to track")
  println("  trace       Show recent command traces")
  println("  help        Show this help message")
  println("")
  println("FEATURES:")
  println("  - Wraps commands with tracing (timing, exit codes, stderr)")
  println("  - Detects errors and matches patterns")
  println("  - Invokes hive agents for error handling")
  println("  - Provides AI context for Claude/Codex")
  println("")
  println("EXAMPLES:")
  println("  shell generate > ~/.config/fish/conf.d/shell-wrappers.fish")
  println("  shell install")
  println("  shell list")
  println("  shell context | jq")
}

fn generate_wrappers() -> Unit {
  let config = @shelllib.default_shell_config()
  println(config.to_fish_script())
}

fn list_commands() -> Unit {
  println("REGISTERED COMMANDS")
  println("=" |> repeat(60))
  println("")
  println("NAME            CATEGORY           DESCRIPTION")
  println("-" |> repeat(60))

  let commands = @shelllib.all_commands()
  for cmd in commands {
    let name = pad_right(cmd.name, 16)
    let category = pad_right(cmd.category, 19)
    println(name + category + cmd.description)
  }

  println("")
  println("Total: " + commands.length().to_string() + " commands")
  println("")
  println("Error patterns per command:")
  println("-" |> repeat(60))

  for cmd in commands {
    if cmd.error_patterns.length() > 0 {
      println("")
      println(cmd.name + " (" + cmd.error_patterns.length().to_string() + " patterns):")
      for pattern in cmd.error_patterns {
        let cat = pad_right(pattern.category.to_string(), 12)
        println("  " + cat + pattern.message)
      }
    }
  }
}

fn install_wrappers() -> Unit {
  let config = @shelllib.default_shell_config()
  let script = config.to_fish_script()
  let home = get_home()
  let config_dir = home + "/.config/fish/conf.d"
  let output_path = config_dir + "/flow-shell-wrappers.fish"

  ensure_dir(config_dir)

  try {
    @fs.write_string_to_file(output_path, script)
    println("Installed shell wrappers to: " + output_path)
    println("")
    println("Wrappers installed for " + config.commands.length().to_string() + " commands:")
    for cmd in config.commands {
      println("  - " + cmd.name)
    }
    println("")
    println("Reload fish config with:")
    println("  source " + output_path)
    println("")
    println("Or restart your terminal.")
  } catch {
    error => println("Error writing file: " + error.to_string())
  }
}

fn show_context() -> Unit {
  // Generate JSON context for AI tools
  let commands = @shelllib.all_commands()

  println("{")
  println("  \"shell\": \"fish\",")

  // CWD
  let cwd = match @sys.get_env_var("PWD") {
    Some(p) => p
    None => "unknown"
  }
  println("  \"cwd\": \"" + escape_json(cwd) + "\",")

  // User
  let user = match @sys.get_env_var("USER") {
    Some(u) => u
    None => "unknown"
  }
  println("  \"user\": \"" + escape_json(user) + "\",")

  // Commands
  println("  \"commands\": [")
  for i, cmd in commands {
    let comma = if i < commands.length() - 1 { "," } else { "" }
    let line = "    {\"name\": \"" + cmd.name + "\", \"category\": \"" + cmd.category + "\", \"description\": \"" + escape_json(cmd.description) + "\"}" + comma
    println(line)
  }
  println("  ],")

  // Recent commands placeholder
  println("  \"recentCommands\": [],")

  // Pending errors placeholder
  println("  \"pendingErrors\": []")
  println("}")
}

fn add_command(name : String) -> Unit {
  println("Adding command: " + name)
  println("")
  println("To add custom commands, create a config file at:")
  println("  ~/.config/flow/shell-commands.toml")
  println("")
  println("Example:")
  println("  [[commands]]")
  println("  name = \"" + name + "\"")
  println("  description = \"Custom command\"")
  println("  category = \"custom\"")
  println("  ")
  println("  [[commands.error_patterns]]")
  println("  pattern = \"error:\"")
  println("  category = \"unknown\"")
  println("")
  println("Then run 'shell generate' to regenerate wrappers.")
}

async fn show_traces() -> Unit {
  let trace_dir = match @sys.get_env_var("__SHELL_TRACE_DIR") {
    Some(d) => d
    None => "/tmp/shell-traces"
  }

  let trace_file = trace_dir + "/traces.jsonl"

  if not(@fs.path_exists(trace_file)) {
    println("No traces found at: " + trace_file)
    println("")
    println("Traces are recorded when commands are run through wrappers.")
    println("Install wrappers first with: shell install")
    return
  }

  println("Recent command traces:")
  println("=" |> repeat(60))
  println("")

  try {
    let (exit_code, stdout_data, stderr_data) = @process.collect_output(
      "sh",
      ["-c", "tail -n 20 " + shell_quote(trace_file)],
      cwd=".",
    )
    if exit_code == 0 {
      let output = stdout_data.text().trim(chars="\n").to_string()
      if output.length() > 0 {
        println(output)
      }
    } else {
      let error_text = stderr_data.text().trim().to_string()
      if error_text.length() > 0 {
        println("Error reading traces: " + error_text)
      }
    }
  } catch {
    error => println("Error reading traces: " + error.to_string())
  }
}

fn get_home() -> String {
  match @sys.get_env_var("HOME") {
    Some(h) => h
    None => "/tmp"
  }
}

fn ensure_dir(path : String) -> Unit {
  if path.length() == 0 || path == "/" || @fs.path_exists(path) {
    return
  }
  let parent = parent_dir(path)
  if parent.length() > 0 && parent != path {
    ensure_dir(parent)
  }
  try {
    @fs.create_dir(path)
  } catch {
    _ => ()
  }
}

fn parent_dir(path : String) -> String {
  if path == "/" {
    return "/"
  }
  let idx = last_index_of_char(path, '/')
  if idx <= 0 {
    ""
  } else {
    substring(path, 0, idx)
  }
}

fn last_index_of_char(text : String, ch : Char) -> Int {
  let mut out = -1
  let mut i = 0
  for c in text {
    if c == ch {
      out = i
    }
    i += 1
  }
  out
}

fn substring(text : String, start : Int, end : Int) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  for c in text {
    if i >= start && i < end {
      out.write_char(c)
    }
    i += 1
  }
  out.to_string()
}

fn shell_quote(value : String) -> String {
  "'" + value.replace(old="'", new="'\\''") + "'"
}

fn pad_right(s : String, width : Int) -> String {
  if s.length() >= width {
    s
  } else {
    s + repeat(" ", width - s.length())
  }
}

fn repeat(s : String, n : Int) -> String {
  let result = StringBuilder::new()
  for _ in 0..<n {
    result.write_string(s)
  }
  result.to_string()
}

fn escape_json(s : String) -> String {
  let result = StringBuilder::new()
  for c in s {
    match c {
      '"' => result.write_string("\\\"")
      '\\' => result.write_string("\\\\")
      '\n' => result.write_string("\\n")
      '\r' => result.write_string("\\r")
      '\t' => result.write_string("\\t")
      _ => result.write_char(c)
    }
  }
  result.to_string()
}
