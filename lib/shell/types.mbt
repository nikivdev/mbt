///|
/// Shell command registry and tracing system

///| Argument types for command parameters
pub enum ArgType {
  StringArg
  NumberArg
  BoolArg
  PathArg
  FileArg
  DirectoryArg
  UrlArg
  JsonArg
} derive(Eq, Show)

///| Error categories
pub enum ErrorCategory {
  NotFound       // command/file not found
  Permission     // permission denied
  Network        // network errors
  Syntax         // syntax/parse errors
  Dependency     // missing dependency
  Config         // configuration error
  Resource       // resource exhausted
  Timeout        // operation timed out
  Auth           // authentication failed
  Conflict       // merge/lock conflicts
  Unknown
} derive(Eq, Show)

///| Error handler actions
pub enum HandlerAction {
  Retry          // retry the command
  Agent(String)  // invoke hive agent
  Suggest(String) // suggest fix to user
  Fallback(String) // run fallback command
  Ignore         // ignore and continue
  Abort(String)  // abort with message
} derive(Eq, Show)

///| Error pattern for matching
pub struct ErrorPattern {
  pattern : String
  category : ErrorCategory
  message : String
} derive(Show)

///| Error handler definition
pub struct ErrorHandler {
  patterns : Array[String]
  action : HandlerAction
  max_retries : Int
  retry_delay_ms : Int
} derive(Show)

///| Tracing configuration
pub struct TracingConfig {
  enabled : Bool
  stdin : Bool
  stdout : Bool
  stderr : Bool
  timing : Bool
  exit_code : Bool
  env : Bool
  log_file : String?
  redact : Array[String]
} derive(Show)

///|
pub fn TracingConfig::default() -> TracingConfig {
  TracingConfig::{
    enabled: true,
    stdin: false,
    stdout: true,
    stderr: true,
    timing: true,
    exit_code: true,
    env: false,
    log_file: None,
    redact: [],
  }
}

///| Command argument definition
pub struct Arg {
  name : String
  arg_type : ArgType
  required : Bool
  description : String
  default_value : String?
} derive(Show)

///| Command definition
pub struct Command {
  name : String
  path : String?
  description : String
  category : String
  aliases : Array[String]
  subcommands : Array[String]
  args : Array[Arg]
  error_patterns : Array[ErrorPattern]
  error_handlers : Array[ErrorHandler]
  tracing : TracingConfig
  env : Map[String, String]
  timeout_ms : Int
  docs_url : String?
  version_cmd : String?
  install_cmd : String?
} derive(Show)

///|
pub fn Command::new(name : String) -> Command {
  Command::{
    name,
    path: None,
    description: "",
    category: "other",
    aliases: [],
    subcommands: [],
    args: [],
    error_patterns: [],
    error_handlers: [],
    tracing: TracingConfig::default(),
    env: {},
    timeout_ms: 0,
    docs_url: None,
    version_cmd: None,
    install_cmd: None,
  }
}

///| Trace record for a command execution
pub struct TraceRecord {
  id : String
  timestamp : Int64
  command : String
  args : Array[String]
  cwd : String
  stdin : String?
  stdout : String?
  stderr : String?
  exit_code : Int
  duration_ms : Int
  error : TraceError?
} derive(Show)

///| Error in a trace
pub struct TraceError {
  category : ErrorCategory
  message : String
  handled : Bool
  handler : String?
} derive(Show)

///| Shell configuration
pub struct ShellConfig {
  version : Int
  commands : Array[Command]
  tracing : TracingConfig
  global_error_handlers : Array[ErrorHandler]
  env : Map[String, String]
  shell : String
  log_dir : String
  ai_context : Bool
  context_file : String
} derive(Show)

///|
pub fn ShellConfig::new() -> ShellConfig {
  ShellConfig::{
    version: 1,
    commands: [],
    tracing: TracingConfig::default(),
    global_error_handlers: [],
    env: {},
    shell: "fish",
    log_dir: "/tmp/shell-traces",
    ai_context: true,
    context_file: "/tmp/shell-context.json",
  }
}

///| AI Context for tools
pub struct AIContext {
  shell : String
  cwd : String
  user : String
  commands : Array[CommandSummary]
  recent_commands : Array[TraceRecord]
  pending_errors : Array[PendingError]
} derive(Show)

///| Summary of a command for AI context
pub struct CommandSummary {
  name : String
  description : String
  category : String
} derive(Show)

///| Pending error for AI context
pub struct PendingError {
  command : String
  error : String
  suggestions : Array[String]
} derive(Show)

///| Convert error category to string
pub fn ErrorCategory::to_string(self : ErrorCategory) -> String {
  match self {
    NotFound => "not-found"
    Permission => "permission"
    Network => "network"
    Syntax => "syntax"
    Dependency => "dependency"
    Config => "config"
    Resource => "resource"
    Timeout => "timeout"
    Auth => "auth"
    Conflict => "conflict"
    Unknown => "unknown"
  }
}
