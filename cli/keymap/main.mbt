///|
/// Keymap CLI - Manage fish shell keybindings declaratively

fn main {
  let args = @sys.get_cli_args()

  if args.length() <= 1 {
    print_help()
    return
  }

  let command = args[1]

  match command {
    "generate" | "gen" => generate_keymaps()
    "list" | "ls" => list_keybindings()
    "install" => install_keymaps()
    "default" => show_default_keymap()
    "vi" => show_vi_keymap()
    "--help" | "-h" | "help" => print_help()
    _ => {
      println("Unknown command: " + command)
      print_help()
    }
  }
}

fn print_help() -> Unit {
  println("keymap - Fish shell keybinding manager")
  println("")
  println("USAGE:")
  println("  keymap <command>")
  println("")
  println("COMMANDS:")
  println("  generate    Generate fish script from keymap config")
  println("  list        List all configured keybindings")
  println("  install     Install keybindings to ~/.config/fish/conf.d/")
  println("  default     Show default enhanced keymap")
  println("  vi          Show vi-mode enhanced keymap")
  println("  help        Show this help message")
  println("")
  println("KEYBINDING TYPES:")
  println("  agent       Invoke a hive agent (e.g., ctrl-alt-g -> git agent)")
  println("  task        Run a flow task (e.g., ctrl-alt-b -> build)")
  println("  shell       Execute shell command")
  println("  function    Call fish function")
  println("  command     Built-in readline command")
  println("")
  println("EXAMPLES:")
  println("  keymap generate > keymaps.fish")
  println("  keymap install")
  println("  keymap list")
}

fn generate_keymaps() -> Unit {
  // Create a config with both default and vi keymaps
  let config = @keymaplib.KeymapConfig::with_keymaps(
    [@keymaplib.default_keymap(), @keymaplib.vi_keymap()],
    "default-enhanced",
  )

  println(config.to_fish_script())
}

fn list_keybindings() -> Unit {
  println("DEFAULT ENHANCED KEYMAP")
  println("=" |> repeat(50))
  println("")

  let default_km = @keymaplib.default_keymap()
  print_keymap(default_km)

  println("")
  println("VI ENHANCED KEYMAP")
  println("=" |> repeat(50))
  println("")

  let vi_km = @keymaplib.vi_keymap()
  print_keymap(vi_km)
}

fn print_keymap(km : @keymaplib.Keymap) -> Unit {
  println("Name: " + km.name)
  println("Description: " + km.description)
  if km.extends.length() > 0 {
    println("Extends: " + km.extends.join(", "))
  }
  println("")
  println("KEYS                TYPE      TARGET                DESCRIPTION")
  println("-" |> repeat(80))

  for binding in km.bindings {
    let keys = pad_right(binding.keys, 20)
    let action = pad_right(binding.action_type.to_string(), 10)
    let target = pad_right(binding.target, 22)
    println(keys + action + target + binding.description)
  }
}

fn show_default_keymap() -> Unit {
  let km = @keymaplib.default_keymap()
  println(km.to_fish_script())
}

fn show_vi_keymap() -> Unit {
  let km = @keymaplib.vi_keymap()
  println(km.to_fish_script())
}

fn install_keymaps() -> Unit {
  let config = @keymaplib.KeymapConfig::with_keymaps(
    [@keymaplib.default_keymap(), @keymaplib.vi_keymap()],
    "default-enhanced",
  )

  let script = config.to_fish_script()
  let home = get_home()
  let config_dir = home + "/.config/fish/conf.d"
  let output_path = config_dir + "/flow-keymaps.fish"

  // Ensure directory exists
  ensure_dir(config_dir)

  // Write the file
  try {
    @fs.write_string_to_file(output_path, script)
    println("Installed keymaps to: " + output_path)
    println("")
    println("Reload fish config with:")
    println("  source " + output_path)
    println("")
    println("Or restart your terminal.")
  } catch {
    error => println("Error writing file: " + error.to_string())
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

fn pad_right(s : String, width : Int) -> String {
  if s.length() >= width {
    s
  } else {
    let padding = repeat(" ", width - s.length())
    s + padding
  }
}

fn repeat(s : String, n : Int) -> String {
  let result = StringBuilder::new()
  for _ in 0..<n {
    result.write_string(s)
  }
  result.to_string()
}
