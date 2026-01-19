///|
/// fishy - create fish wrappers quickly
///
/// Usage:
///   fishy wrap <command...> [for|as|named|to] <name>
///   fishy <command...> [for|as|named|to] <name>
///   fishy -h | --help
///
/// Examples:
///   fishy wrap zed-open code for we
///   fishy hive agent fish to fa

let program_name = "fishy"
let target_file = "/Users/nikiv/config/fish/fn.fish"
let program_version = "0.1.0"

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
    if tok == "for" || tok == "as" || tok == "named" || tok == "to" {
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
    "PY\n" +
    "WRAP=\"fishy\" " +
    "CMD=\"fishy\" " +
    "WRAPS=\"fishy\" " +
    "DESC=\"fishy - fish wrapper helper\" " +
    "python - <<'PY'\n" +
    "import os, re, pathlib\n" +
    "wrap = os.environ.get('WRAP', 'fishy')\n" +
    "cmd = os.environ.get('CMD', 'fishy')\n" +
    "wraps_cmd = os.environ.get('WRAPS', 'fishy')\n" +
    "desc = os.environ.get('DESC', 'fishy - fish wrapper helper')\n" +
    "path = pathlib.Path('" + target_file + "')\n" +
    "content = path.read_text() if path.exists() else ''\n" +
    "pattern = re.compile(r'^function ' + re.escape(wrap) + r' .*?^end\\\\n', re.M | re.S)\n" +
    "content = pattern.sub('', content)\n" +
    "func = f\"\"\"function {wrap} --wraps={wraps_cmd} --description \\\"{desc}\\\"\\n\"\"\"\n" +
    "func += f\"    command {cmd} $argv\\n\"\n" +
    "func += f\"    and source " + target_file + "\\n\"\n" +
    "func += \"end\\n\"\n" +
    "func += f\"complete -c {wrap} -w {wraps_cmd}\\n\"\n" +
    "if content and not content.endswith('\\\\n'):\n" +
    "    content += '\\\\n'\n" +
    "content += func\n" +
    "path.parent.mkdir(parents=True, exist_ok=True)\n" +
    "path.write_text(content)\n" +
    "PY\n" +
    "if test -f /Users/nikiv/.config/fish/functions/" + info.wrapper + ".fish; then " +
    "rm -f /Users/nikiv/.config/fish/functions/" + info.wrapper + ".fish; " +
    "echo 'Removed /Users/nikiv/.config/fish/functions/" + info.wrapper + ".fish'; " +
    "fi\n" +
    "echo 'Run: source " + target_file + "'\n"
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
