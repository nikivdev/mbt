///|
/// Predefined shell commands with error patterns and handlers

///| Create git command definition
pub fn git_command() -> Command {
  Command::{
    name: "git",
    path: None,
    description: "Distributed version control system",
    category: "vcs",
    aliases: ["g"],
    subcommands: [
      "add", "commit", "push", "pull", "checkout", "branch", "merge",
      "rebase", "stash", "log", "diff", "status", "clone", "fetch",
      "reset", "tag", "remote", "cherry-pick", "bisect",
    ],
    args: [],
    error_patterns: [
      ErrorPattern::{
        pattern: "fatal: not a git repository",
        category: Config,
        message: "Not in a git repository",
      },
      ErrorPattern::{
        pattern: "error: failed to push",
        category: Conflict,
        message: "Push rejected, pull first",
      },
      ErrorPattern::{
        pattern: "CONFLICT",
        category: Conflict,
        message: "Merge conflict detected",
      },
      ErrorPattern::{
        pattern: "Permission denied",
        category: Permission,
        message: "Permission denied",
      },
      ErrorPattern::{
        pattern: "Could not resolve host",
        category: Network,
        message: "Network error",
      },
      ErrorPattern::{
        pattern: "Authentication failed",
        category: Auth,
        message: "Authentication failed",
      },
      ErrorPattern::{
        pattern: "Your branch is behind",
        category: Conflict,
        message: "Branch needs update",
      },
    ],
    error_handlers: [
      ErrorHandler::{
        patterns: ["not a git repository"],
        action: Suggest("Run 'git init' to initialize a repository"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
      ErrorHandler::{
        patterns: ["failed to push"],
        action: Agent("git-sync"),
        max_retries: 1,
        retry_delay_ms: 1000,
      },
      ErrorHandler::{
        patterns: ["CONFLICT"],
        action: Agent("git-conflict"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
      ErrorHandler::{
        patterns: ["Authentication failed"],
        action: Agent("git-auth"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
    ],
    tracing: TracingConfig::{
      enabled: true,
      stdin: false,
      stdout: true,
      stderr: true,
      timing: true,
      exit_code: true,
      env: false,
      log_file: None,
      redact: [],
    },
    env: {},
    timeout_ms: 60000,
    docs_url: Some("https://git-scm.com/docs"),
    version_cmd: Some("git --version"),
    install_cmd: None,
  }
}

///| Create npm command definition
pub fn npm_command() -> Command {
  Command::{
    name: "npm",
    path: None,
    description: "Node package manager",
    category: "package-manager",
    aliases: [],
    subcommands: [
      "install", "run", "test", "build", "publish", "update",
      "audit", "ci", "init", "link", "uninstall", "cache",
    ],
    args: [],
    error_patterns: [
      ErrorPattern::{
        pattern: "ENOENT",
        category: NotFound,
        message: "File or directory not found",
      },
      ErrorPattern::{
        pattern: "EACCES",
        category: Permission,
        message: "Permission denied",
      },
      ErrorPattern::{
        pattern: "ERESOLVE",
        category: Dependency,
        message: "Dependency resolution failed",
      },
      ErrorPattern::{
        pattern: "npm ERR!",
        category: Unknown,
        message: "npm error",
      },
      ErrorPattern::{
        pattern: "ETARGET",
        category: Dependency,
        message: "Package version not found",
      },
    ],
    error_handlers: [
      ErrorHandler::{
        patterns: ["ERESOLVE", "ETARGET"],
        action: Agent("npm-deps"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
      ErrorHandler::{
        patterns: ["ENOENT.*package.json"],
        action: Suggest("Run 'npm init' to create package.json"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
    ],
    tracing: TracingConfig::default(),
    env: {},
    timeout_ms: 300000,
    docs_url: Some("https://docs.npmjs.com/"),
    version_cmd: Some("npm --version"),
    install_cmd: Some("curl -fsSL https://get.pnpm.io/install.sh | sh -"),
  }
}

///| Create pnpm command definition
pub fn pnpm_command() -> Command {
  Command::{
    name: "pnpm",
    path: None,
    description: "Fast, disk space efficient package manager",
    category: "package-manager",
    aliases: ["p"],
    subcommands: ["install", "run", "test", "build", "add", "remove", "update", "dlx"],
    args: [],
    error_patterns: [
      ErrorPattern::{
        pattern: "ERR_PNPM",
        category: Unknown,
        message: "pnpm error",
      },
      ErrorPattern::{
        pattern: "LOCKFILE_OUT_OF_DATE",
        category: Dependency,
        message: "Lockfile out of date",
      },
    ],
    error_handlers: [
      ErrorHandler::{
        patterns: ["LOCKFILE_OUT_OF_DATE"],
        action: Suggest("Run 'pnpm install' to update lockfile"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
    ],
    tracing: TracingConfig::default(),
    env: {},
    timeout_ms: 300000,
    docs_url: Some("https://pnpm.io/"),
    version_cmd: Some("pnpm --version"),
    install_cmd: Some("curl -fsSL https://get.pnpm.io/install.sh | sh -"),
  }
}

///| Create docker command definition
pub fn docker_command() -> Command {
  Command::{
    name: "docker",
    path: None,
    description: "Container platform",
    category: "containers",
    aliases: ["d"],
    subcommands: [
      "run", "build", "push", "pull", "ps", "images", "exec",
      "logs", "compose", "stop", "rm", "rmi", "network", "volume",
    ],
    args: [],
    error_patterns: [
      ErrorPattern::{
        pattern: "Cannot connect to the Docker daemon",
        category: Config,
        message: "Docker daemon not running",
      },
      ErrorPattern::{
        pattern: "image not found",
        category: NotFound,
        message: "Docker image not found",
      },
      ErrorPattern::{
        pattern: "port is already allocated",
        category: Resource,
        message: "Port already in use",
      },
      ErrorPattern::{
        pattern: "no space left on device",
        category: Resource,
        message: "Disk full",
      },
    ],
    error_handlers: [
      ErrorHandler::{
        patterns: ["Cannot connect.*daemon"],
        action: Suggest("Start Docker Desktop or run 'sudo systemctl start docker'"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
      ErrorHandler::{
        patterns: ["no space left"],
        action: Agent("docker-cleanup"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
    ],
    tracing: TracingConfig::default(),
    env: {},
    timeout_ms: 300000,
    docs_url: Some("https://docs.docker.com/"),
    version_cmd: Some("docker --version"),
    install_cmd: None,
  }
}

///| Create moon command definition (MoonBit)
pub fn moon_command() -> Command {
  Command::{
    name: "moon",
    path: None,
    description: "MoonBit build tool",
    category: "build",
    aliases: ["m"],
    subcommands: ["build", "run", "test", "check", "new", "update", "clean", "fmt"],
    args: [],
    error_patterns: [
      ErrorPattern::{
        pattern: "error:",
        category: Syntax,
        message: "Compilation error",
      },
      ErrorPattern::{
        pattern: "Cannot find package",
        category: Dependency,
        message: "Package not found",
      },
    ],
    error_handlers: [
      ErrorHandler::{
        patterns: ["Cannot find package"],
        action: Suggest("Run 'moon update' to fetch dependencies"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
    ],
    tracing: TracingConfig::default(),
    env: {},
    timeout_ms: 120000,
    docs_url: Some("https://docs.moonbitlang.com/"),
    version_cmd: Some("moon version"),
    install_cmd: Some("curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash"),
  }
}

///| Create cargo command definition (Rust)
pub fn cargo_command() -> Command {
  Command::{
    name: "cargo",
    path: None,
    description: "Rust package manager",
    category: "build",
    aliases: ["c"],
    subcommands: ["build", "run", "test", "check", "new", "add", "remove", "update", "fmt", "clippy"],
    args: [],
    error_patterns: [
      ErrorPattern::{
        pattern: "error[E",
        category: Syntax,
        message: "Compilation error",
      },
      ErrorPattern::{
        pattern: "could not compile",
        category: Syntax,
        message: "Build failed",
      },
      ErrorPattern::{
        pattern: "failed to select a version",
        category: Dependency,
        message: "Dependency resolution failed",
      },
    ],
    error_handlers: [],
    tracing: TracingConfig::default(),
    env: {},
    timeout_ms: 300000,
    docs_url: Some("https://doc.rust-lang.org/cargo/"),
    version_cmd: Some("cargo --version"),
    install_cmd: Some("curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"),
  }
}

///| Create kubectl command definition
pub fn kubectl_command() -> Command {
  Command::{
    name: "kubectl",
    path: None,
    description: "Kubernetes CLI",
    category: "containers",
    aliases: ["k"],
    subcommands: ["get", "apply", "delete", "describe", "logs", "exec", "port-forward", "scale"],
    args: [],
    error_patterns: [
      ErrorPattern::{
        pattern: "Unable to connect to the server",
        category: Network,
        message: "Cannot connect to cluster",
      },
      ErrorPattern::{
        pattern: "error: the server doesn't have a resource type",
        category: NotFound,
        message: "Resource type not found",
      },
      ErrorPattern::{
        pattern: "forbidden",
        category: Permission,
        message: "Access denied",
      },
    ],
    error_handlers: [
      ErrorHandler::{
        patterns: ["Unable to connect"],
        action: Suggest("Check kubectl config with 'kubectl config current-context'"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
    ],
    tracing: TracingConfig::default(),
    env: {},
    timeout_ms: 60000,
    docs_url: Some("https://kubernetes.io/docs/reference/kubectl/"),
    version_cmd: Some("kubectl version --client"),
    install_cmd: None,
  }
}

///| Create ssh command definition
pub fn ssh_command() -> Command {
  Command::{
    name: "ssh",
    path: None,
    description: "Secure shell",
    category: "network",
    aliases: [],
    subcommands: [],
    args: [],
    error_patterns: [
      ErrorPattern::{
        pattern: "Connection refused",
        category: Network,
        message: "Connection refused",
      },
      ErrorPattern::{
        pattern: "Permission denied",
        category: Auth,
        message: "Authentication failed",
      },
      ErrorPattern::{
        pattern: "Host key verification failed",
        category: Auth,
        message: "Host key mismatch",
      },
      ErrorPattern::{
        pattern: "Connection timed out",
        category: Timeout,
        message: "Connection timed out",
      },
    ],
    error_handlers: [
      ErrorHandler::{
        patterns: ["Host key verification failed"],
        action: Suggest("Remove old key with 'ssh-keygen -R <host>'"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
    ],
    tracing: TracingConfig::{
      enabled: true,
      stdin: false,
      stdout: false,
      stderr: true,
      timing: true,
      exit_code: true,
      env: false,
      log_file: None,
      redact: ["password", "PASS", "KEY"],
    },
    env: {},
    timeout_ms: 30000,
    docs_url: Some("https://man.openbsd.org/ssh"),
    version_cmd: Some("ssh -V"),
    install_cmd: None,
  }
}

///| Create curl command definition
pub fn curl_command() -> Command {
  Command::{
    name: "curl",
    path: None,
    description: "Transfer data with URLs",
    category: "network",
    aliases: [],
    subcommands: [],
    args: [],
    error_patterns: [
      ErrorPattern::{
        pattern: "Could not resolve host",
        category: Network,
        message: "DNS resolution failed",
      },
      ErrorPattern::{
        pattern: "Connection refused",
        category: Network,
        message: "Connection refused",
      },
      ErrorPattern::{
        pattern: "SSL certificate problem",
        category: Auth,
        message: "SSL certificate error",
      },
      ErrorPattern::{
        pattern: "Connection timed out",
        category: Timeout,
        message: "Connection timed out",
      },
    ],
    error_handlers: [],
    tracing: TracingConfig::{
      enabled: true,
      stdin: false,
      stdout: false,
      stderr: true,
      timing: true,
      exit_code: true,
      env: false,
      log_file: None,
      redact: ["Authorization", "Bearer", "token", "api_key"],
    },
    env: {},
    timeout_ms: 60000,
    docs_url: Some("https://curl.se/docs/"),
    version_cmd: Some("curl --version"),
    install_cmd: None,
  }
}

///| Create make command definition
pub fn make_command() -> Command {
  Command::{
    name: "make",
    path: None,
    description: "Build automation tool",
    category: "build",
    aliases: [],
    subcommands: [],
    args: [],
    error_patterns: [
      ErrorPattern::{
        pattern: "No rule to make target",
        category: NotFound,
        message: "Target not found",
      },
      ErrorPattern::{
        pattern: "No such file or directory",
        category: NotFound,
        message: "File not found",
      },
      ErrorPattern::{
        pattern: "Error 1",
        category: Syntax,
        message: "Build failed",
      },
    ],
    error_handlers: [],
    tracing: TracingConfig::default(),
    env: {},
    timeout_ms: 600000,
    docs_url: Some("https://www.gnu.org/software/make/manual/"),
    version_cmd: Some("make --version"),
    install_cmd: None,
  }
}

///| Get all predefined commands
pub fn all_commands() -> Array[Command] {
  [
    git_command(),
    npm_command(),
    pnpm_command(),
    docker_command(),
    moon_command(),
    cargo_command(),
    kubectl_command(),
    ssh_command(),
    curl_command(),
    make_command(),
  ]
}

///| Create a default shell config with all common commands
pub fn default_shell_config() -> ShellConfig {
  ShellConfig::{
    version: 1,
    commands: all_commands(),
    tracing: TracingConfig::default(),
    global_error_handlers: [
      ErrorHandler::{
        patterns: ["command not found"],
        action: Agent("install-helper"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
      ErrorHandler::{
        patterns: ["permission denied"],
        action: Suggest("Try with sudo or check file permissions"),
        max_retries: 0,
        retry_delay_ms: 0,
      },
    ],
    env: {},
    shell: "fish",
    log_dir: "/tmp/shell-traces",
    ai_context: true,
    context_file: "/tmp/shell-context.json",
  }
}
