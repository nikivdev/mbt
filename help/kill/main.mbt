///|
/// kill-help - Safe kill helper (no execution)
///
/// Usage:
///   kill-help <port|pid> [--port|--pid] [--show]
///
/// Examples:
///   kill-help 5000
///   kill-help 12345 --pid
///   kill-help 5000 --show

let program_name = "kill-help"

async fn main {
  let args = @sys.get_cli_args()
  if args.length() <= 1 {
    print_usage()
    return
  }

  let mut target = ""
  let mut force_pid = false
  let mut force_port = false
  let mut show = false

  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--help" || arg == "-h" {
      print_usage()
      return
    } else if arg == "--pid" {
      force_pid = true
    } else if arg == "--port" {
      force_port = true
    } else if arg == "--show" {
      show = true
    } else if target.length() == 0 {
      target = arg
    }
    i += 1
  }

  if target.length() == 0 {
    print_usage()
    return
  }

  let is_number = is_digits(target)
  if !is_number {
    println("Error: target must be a numeric pid or port")
    return
  }
  let kind = if force_pid {
    "pid"
  } else if force_port {
    "port"
  } else if is_number {
    "port"
  } else {
    "pid"
  }

  println("kill-help: preview only (no commands executed)")
  println("")

  if kind == "port" {
    if !is_valid_port(target) {
      println("Error: port must be in the range 1-65535")
      return
    }
    preview_port(target, show)
  } else {
    if !is_valid_pid(target) {
      println("Error: pid must be greater than 0")
      return
    }
    preview_pid(target, show)
  }
}

fn print_usage() -> Unit {
  println("")
  println("\{program_name} - Safe kill helper (no execution)")
  println("")
  println("Usage:")
  println("  \{program_name} <port|pid> [--port|--pid] [--show]")
  println("")
  println("Examples:")
  println("  \{program_name} 5000")
  println("  \{program_name} 12345 --pid")
  println("  \{program_name} 5000 --show")
}

async fn preview_port(value : String, show : Bool) -> Unit {
  println("Target: port \{value}")
  println("")
  println("Preview command:")
  println("  lsof -nP -iTCP:\{value} -sTCP:LISTEN")
  println("")
  println("Kill (TERM):")
  println("  kill -TERM <pid>")
  println("")
  println("Force (KILL):")
  println("  kill -KILL <pid>")
  println("")
  println("One-liner (TERM):")
  println("  lsof -ti tcp:\{value} | xargs -r kill -TERM")
  println("")

  if show {
    if command_exists("lsof") {
      let cmd = "lsof -nP -iTCP:\{value} -sTCP:LISTEN"
      println("Output:")
      let result = run_shell(cmd, ".")
      if result.stdout.length() > 0 {
        println(result.stdout.trim())
      } else if result.stderr.length() > 0 {
        println(result.stderr.trim())
      } else {
        println("(no output)")
      }
    } else {
      println("lsof not found. Install lsof or run the preview command manually.")
    }
  }
}

async fn preview_pid(value : String, show : Bool) -> Unit {
  println("Target: pid \{value}")
  println("")
  println("Preview command:")
  println("  ps -p \{value} -o pid,ppid,command")
  println("")
  println("Kill (TERM):")
  println("  kill -TERM \{value}")
  println("")
  println("Force (KILL):")
  println("  kill -KILL \{value}")
  println("")

  if show {
    if command_exists("ps") {
      let cmd = "ps -p \{value} -o pid,ppid,command"
      println("Output:")
      let result = run_shell(cmd, ".")
      if result.stdout.length() > 0 {
        println(result.stdout.trim())
      } else if result.stderr.length() > 0 {
        println(result.stderr.trim())
      } else {
        println("(no output)")
      }
    }
  }
}

fn is_digits(value : String) -> Bool {
  if value.length() == 0 {
    return false
  }
  for ch in value {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

fn is_valid_port(value : String) -> Bool {
  let port = parse_int_or_zero(value)
  port > 0 && port <= 65535
}

fn is_valid_pid(value : String) -> Bool {
  parse_int_or_zero(value) > 0
}

fn parse_int_or_zero(value : String) -> Int {
  let mut out = 0
  for ch in value {
    if ch >= '0' && ch <= '9' {
      out = out * 10 + (ch.to_int() - 48)
    }
  }
  out
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

async fn command_exists(name : String) -> Bool {
  let cmd = "command -v " + shell_quote(name) + " >/dev/null 2>&1; echo ok"
  let result = run_shell(cmd, ".")
  result.exit_code == 0 && result.stdout.trim() == "ok"
}

fn shell_quote(value : String) -> String {
  "'" + value.replace(old="'", new="'\\''") + "'"
}
