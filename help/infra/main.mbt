///|
/// infra-help - Infra host deploy helper
///
/// Usage:
///   infra-help help
///   infra-help deploy [--root <path>] [-- <args>]
///   infra-help host <args...>
///   infra-help <args...>
///
/// Notes:
///   - Prefer `f infra-deploy` (flow task) or `f deploy host` in Flow repos
///   - Requires [host] section in flow.toml (host/user/path/service/setup/env_file)
///   - env_file (e.g. scripts/*.env) is copied to remote as .env

let program_name = "infra-help"

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

  if command == "deploy" {
    deploy_command(args, 2)
    return
  }

  passthrough_infra(args, 1)
}

fn print_usage() -> Unit {
  println("infra-help - infra host deploy helper")
  println("")
  println("Usage:")
  println("  infra-help deploy [--root <path>] [-- <args>]")
  println("  infra-help host <args...>")
  println("  infra-help <args...>")
  println("")
  println("Notes:")
  println("  - Prefer `f infra-deploy` (task) or `f deploy host` in Flow repos")
  println("  - Requires [host] in flow.toml (host/user/path/service/setup/env_file)")
  println("  - env_file copied to remote as .env")
  println("")
  println("Examples:")
  println("  infra-help deploy --root ~/code/lang/cpp/stream")
  println("  infra-help host deploy --setup")
}

async fn deploy_command(args : Array[String], start : Int) -> Unit raise {
  let cwd = get_cwd()
  let parsed = parse_root_and_args(args, start, cwd)
  let check = run_shell("command -v f >/dev/null 2>&1", cwd)
  if check.exit_code != 0 {
    println("Flow CLI not found. Install and run `f infra-deploy`.")
    return
  }

  let run_args : Array[String] = []
  run_args.push("infra-deploy")
  for arg in parsed.args {
    run_args.push(arg)
  }

  let result = run_exec("f", run_args, parsed.root)
  if result.stdout.length() > 0 {
    println(result.stdout.trim())
  }
  if result.stderr.length() > 0 {
    println(result.stderr.trim())
  }
}

async fn passthrough_infra(args : Array[String], start : Int) -> Unit raise {
  let cwd = get_cwd()
  let check = run_shell("command -v infra >/dev/null 2>&1", cwd)
  if check.exit_code != 0 {
    println("infra CLI not found. Try: f infra-deploy")
    return
  }

  let passthrough = args_slice_to_array(args, start)
  let result = run_exec("infra", passthrough, cwd)
  if result.stdout.length() > 0 {
    println(result.stdout.trim())
  }
  if result.stderr.length() > 0 {
    println(result.stderr.trim())
  }
}

struct RootArgs {
  root : String
  args : Array[String]
}

fn parse_root_and_args(
  args : Array[String],
  start : Int,
  default_root : String,
) -> RootArgs {
  let mut root = default_root
  let rest : Array[String] = []
  let mut i = start
  while i < args.length() {
    let arg = args[i]
    if arg == "--root" || arg == "-r" {
      i += 1
      if i < args.length() {
        root = args[i]
      }
    } else if arg == "--" {
      i += 1
      while i < args.length() {
        rest.push(args[i])
        i += 1
      }
      break
    } else {
      rest.push(arg)
    }
    i += 1
  }
  RootArgs::{ root, args: rest }
}

fn args_slice_to_array(args : Array[String], start : Int) -> Array[String] {
  let result : Array[String] = []
  let mut i = start
  while i < args.length() {
    result.push(args[i])
    i = i + 1
  }
  result
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
