// Fast context gathering CLI for AI assistants
// Extremely optimized for speed - no API calls, local heuristics only

fn main {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    print_usage()
    return
  }

  // Parse args: ctx <path> [task] [--output file] [--max-size N] [-O/--optimized]
  let mut path = "."
  let mut path_set = false
  let mut task = ""
  let mut output_path : String? = None
  let mut max_size = 500000
  let mut optimized = false

  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--output" || arg == "-o" {
      i += 1
      if i < args.length() {
        output_path = Some(args[i])
      }
    } else if arg == "--max-size" {
      i += 1
      if i < args.length() {
        max_size = try { @strconv.parse_int(args[i]) } catch { _ => 500000 }
      }
    } else if arg == "-O" || arg == "--optimized" {
      optimized = true
    } else if arg == "--help" || arg == "-h" {
      print_usage()
      return
    } else if not(path_set) && not(arg.starts_with("-")) {
      path = arg
      path_set = true
    } else if task == "" && not(arg.starts_with("-")) {
      task = arg
    }
    i += 1
  }

  // Run context gathering
  gather_context(path, task, max_size, output_path, optimized)
}

fn print_usage() -> Unit {
  println("ctx - Fast context gathering for AI assistants")
  println("")
  println("Usage: ctx [path] [task] [options]")
  println("")
  println("Options:")
  println("  -o, --output FILE   Write to file instead of stdout")
  println("  --max-size N        Maximum context size in bytes (default: 500000)")
  println("  -O, --optimized     Skip noise dirs, prioritize essential files")
  println("  -h, --help          Show this help")
  println("")
  println("Examples:")
  println("  ctx .                     Pack current directory")
  println("  ctx . \"fix login bug\"     Gather context for task")
  println("  ctx ./src -O              Optimized mode")
}

// Stopwords to filter from task queries
let stopwords : Array[String] = [
  "the", "and", "for", "with", "from", "this", "that", "your", "you",
  "are", "was", "were", "fix", "add", "update", "change", "implement",
  "create", "make", "build", "how", "what", "why", "a", "an", "to", "in",
  "of", "is", "it", "on", "at", "by", "as", "or", "be", "do", "does",
  "can", "could", "would", "should", "will", "need", "want", "like",
]

// Convert char to lowercase
fn char_to_lower(c : Char) -> Char {
  let code = c.to_int()
  if code >= 65 && code <= 90 {
    Char::from_int(code + 32)
  } else {
    c
  }
}

// Convert string to lowercase
fn to_lower(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    buf.write_char(char_to_lower(c))
  }
  buf.to_string()
}

// Find last index of character in string
fn last_index_of_char(s : String, ch : Char) -> Int {
  let mut last = -1
  for i, c in s {
    if c == ch {
      last = i
    }
  }
  last
}

// Strip chars from start
fn strip_start(s : String, chars : String) -> String {
  let mut start = 0
  for i, c in s {
    let mut found = false
    for ch in chars {
      if c == ch {
        found = true
        break
      }
    }
    if found {
      start = i + 1
    } else {
      break
    }
  }
  s.substring(start~)
}

// Strip chars from end
fn strip_end(s : String, chars : String) -> String {
  let len = s.length()
  if len == 0 {
    return s
  }
  let chars_arr : Array[Char] = []
  for c in chars {
    chars_arr.push(c)
  }
  let mut end = len
  let mut i = len - 1
  while i >= 0 {
    let c = s.charcode_at(i)
    let mut found = false
    for ch in chars_arr {
      if c == ch.to_int() {
        found = true
        break
      }
    }
    if found {
      end = i
      i -= 1
    } else {
      break
    }
  }
  s.substring(end=end)
}

// Tokenize a task query into searchable terms
fn tokenize_query(query : String) -> Array[String] {
  let tokens : Array[String] = []
  let words = to_lower(query).split(" ")
  for word in words {
    let clean = strip_end(strip_start(word.to_string(), "\"'`"), "\"'`.,;:!?")
    if clean.length() >= 2 && not(stopwords.contains(clean)) {
      tokens.push(clean)
    }
  }
  tokens
}

// Count how many tokens appear in text
fn count_token_hits(text : String, tokens : Array[String]) -> Int {
  let lower = to_lower(text)
  let mut count = 0
  for token in tokens {
    if lower.contains(token) {
      count += 1
    }
  }
  count
}

// File priority: 0=entry points, 1=source, 2=config, 3=docs, 4=other
fn file_priority(path : String) -> Int {
  let name = basename(path)
  let ext = extension(path)

  // Priority 0: Main entry points
  if name == "main.rs" || name == "lib.rs" || name == "main.py" ||
     name == "app.py" || name == "index.ts" || name == "index.js" ||
     name == "mod.rs" || name == "main.mbt" || name == "main.go" {
    return 0
  }

  // Priority 1: Source code
  if ["rs", "py", "go", "ts", "tsx", "js", "jsx", "mbt", "swift", "kt",
      "java", "c", "cpp", "h", "hpp", "cs", "rb", "php", "zig", "nim",
      "ex", "exs", "clj", "scala"].contains(ext) {
    return 1
  }

  // Priority 2: Config files
  if name == "Cargo.toml" || name == "pyproject.toml" || name == "package.json" ||
     name == "moon.mod.json" || name == "moon.pkg.json" || name == "go.mod" ||
     name == "Makefile" || name == "flow.toml" {
    return 2
  }
  if ["toml", "yaml", "yml", "json"].contains(ext) {
    return 2
  }

  // Priority 3: Documentation
  if ["md", "txt", "rst"].contains(ext) {
    return 3
  }

  // Priority 4: Everything else
  4
}

// Base score for priority
fn base_score(priority : Int) -> Int {
  match priority {
    0 => 60
    1 => 35
    2 => 15
    3 => 6
    4 => 3
    _ => 1
  }
}

// Noise directories to skip in optimized mode
let noise_dirs : Array[String] = [
  "__pycache__", "node_modules", ".next", "checkpoints", "checkpoint",
  ".cache", "cache", "dist", "build", "target", ".pytest_cache",
  ".mypy_cache", ".ruff_cache", "venv", ".venv", "env", ".tox",
  "coverage", ".coverage", "htmlcov", ".eggs", "_build", ".git",
  ".hg", ".svn", ".mooncakes", ".ai", ".ai-worktrees",
]

// Check if path should be skipped
fn should_skip_path(path : String) -> Bool {
  let lower = to_lower(path)
  for dir in noise_dirs {
    if lower.contains("/\{dir}/") || lower.ends_with("/\{dir}") {
      return true
    }
  }
  false
}

// Binary file extensions
let binary_exts : Array[String] = [
  "png", "jpg", "jpeg", "gif", "bmp", "ico", "webp", "svg",
  "mp3", "mp4", "wav", "avi", "mov", "mkv", "flv",
  "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
  "zip", "tar", "gz", "bz2", "7z", "rar",
  "exe", "dll", "so", "dylib", "a", "o", "obj",
  "wasm", "pyc", "pyo", "class", "jar",
  "ttf", "otf", "woff", "woff2", "eot",
  "db", "sqlite", "sqlite3",
]

fn is_binary(path : String) -> Bool {
  let ext = extension(path)
  binary_exts.contains(ext)
}

// Get file extension
fn extension(path : String) -> String {
  let idx = last_index_of_char(path, '.')
  if idx >= 0 && idx < path.length() - 1 {
    path.substring(start=idx + 1)
  } else {
    ""
  }
}

// Get basename
fn basename(path : String) -> String {
  let idx = last_index_of_char(path, '/')
  if idx >= 0 {
    path.substring(start=idx + 1)
  } else {
    path
  }
}

// Get language hint for code fence
fn language_hint(path : String) -> String {
  let ext = extension(path)
  match ext {
    "rs" => "rust"
    "py" => "python"
    "js" => "javascript"
    "ts" => "typescript"
    "tsx" => "tsx"
    "jsx" => "jsx"
    "go" => "go"
    "mbt" => "moonbit"
    "java" => "java"
    "kt" => "kotlin"
    "swift" => "swift"
    "c" | "h" => "c"
    "cpp" | "hpp" | "cc" => "cpp"
    "rb" => "ruby"
    "php" => "php"
    "sh" | "bash" => "bash"
    "fish" => "fish"
    "toml" => "toml"
    "yaml" | "yml" => "yaml"
    "json" => "json"
    "md" => "markdown"
    "sql" => "sql"
    "html" => "html"
    "css" => "css"
    _ => ext
  }
}

// File candidate for scoring
struct Candidate {
  rel_path : String
  full_path : String
  score : Int
  priority : Int
  content : String?
}

// Main context gathering
fn gather_context(
  path : String,
  task : String,
  max_size : Int,
  output_path : String?,
  optimized : Bool
) -> Unit {
  let tokens = tokenize_query(task)
  let candidates : Array[Candidate] = []

  // Walk directory
  walk_dir(path, path, tokens, optimized, candidates)

  if candidates.length() == 0 {
    println("No relevant files found")
    return
  }

  // Sort by score descending
  candidates.sort_by(fn(a, b) {
    if b.score != a.score {
      b.score - a.score
    } else if a.priority != b.priority {
      a.priority - b.priority
    } else {
      a.rel_path.compare(b.rel_path)
    }
  })

  // Build context output
  let context = StringBuilder::new()
  let mut total_size = 0
  let mut file_count = 0
  let files_included : Array[String] = []

  if task != "" {
    context.write_string("# Task: ")
    context.write_string(task)
    context.write_string("\n\n")
  }

  context.write_string("<file_contents>\n")

  for candidate in candidates {
    // Read file if not cached
    let content = match candidate.content {
      Some(c) => c
      None => {
        match read_file_sync(candidate.full_path) {
          Ok(c) => c
          Err(_) => continue
        }
      }
    }

    let lang = language_hint(candidate.full_path)
    let section = "File: \{candidate.rel_path}\n```\{lang}\n\{content}\n```\n\n"

    if total_size + section.length() > max_size {
      continue
    }

    total_size += section.length()
    context.write_string(section)
    files_included.push(candidate.rel_path)
    file_count += 1
  }

  context.write_string("</file_contents>\n")

  let result = context.to_string()

  // Output
  match output_path {
    Some(out) => {
      write_file_sync(out, result)
      // Print summary to stderr so it doesn't mix with output
      println("Wrote \{file_count} files (\{total_size} bytes) to \{out}")
    }
    None => {
      // Print context to stdout for piping (without trailing newline)
      println(result)
    }
  }
}

// Walk directory recursively
fn walk_dir(
  root : String,
  current : String,
  tokens : Array[String],
  optimized : Bool,
  candidates : Array[Candidate]
) -> Unit {
  // Check gitignore
  let gitignore_path = "\{current}/.gitignore"
  let ignore_patterns : Array[String] = match read_file_sync(gitignore_path) {
    Ok(content) => parse_gitignore(content)
    Err(_) => []
  }

  let entries = list_dir_sync(current)
  for entry in entries {
    let full = "\{current}/\{entry}"
    let rel = if root == current {
      entry
    } else {
      full.substring(start=root.length() + 1)
    }

    // Skip hidden
    if entry.starts_with(".") && entry != ".gitignore" {
      continue
    }

    // Skip if matches gitignore
    if matches_gitignore(rel, ignore_patterns) {
      continue
    }

    if is_dir_sync(full) {
      // Skip noise dirs
      if optimized && noise_dirs.contains(entry) {
        continue
      }
      walk_dir(root, full, tokens, optimized, candidates)
    } else {
      // Skip binary
      if is_binary(full) {
        continue
      }

      let priority = file_priority(full)
      let path_hits = count_token_hits(rel, tokens)

      // In optimized mode, skip low priority files with no hits
      if optimized && priority >= 3 && path_hits == 0 {
        continue
      }

      let mut score = base_score(priority) + (path_hits * 12)
      let mut matched = path_hits > 0
      let mut cached_content : String? = None

      // Check content for high-priority files
      if tokens.length() > 0 && not(matched) && priority <= 1 {
        match read_file_sync(full) {
          Ok(content) => {
            let content_hits = count_token_hits(content, tokens)
            if content_hits > 0 {
              score += content_hits * 4
              matched = true
              cached_content = Some(content)
            }
          }
          Err(_) => ()
        }
      }

      // Add to candidates
      if tokens.length() == 0 || matched || priority <= 2 {
        candidates.push(Candidate::{
          rel_path: rel,
          full_path: full,
          score,
          priority,
          content: cached_content,
        })
      }
    }
  }
}

// Parse gitignore patterns
fn parse_gitignore(content : String) -> Array[String] {
  let patterns : Array[String] = []
  for line in content.split("\n") {
    let trimmed = strip_end(strip_start(line.to_string(), " \t"), " \t\r")
    if trimmed != "" && not(trimmed.starts_with("#")) {
      patterns.push(trimmed)
    }
  }
  patterns
}

// Check if path matches gitignore patterns
fn matches_gitignore(path : String, patterns : Array[String]) -> Bool {
  for pattern in patterns {
    if pattern.ends_with("/") {
      // Directory pattern
      let dir = strip_end(pattern, "/")
      if path.starts_with(dir) || path.contains("/\{dir}/") {
        return true
      }
    } else if pattern.starts_with("*") {
      // Wildcard suffix
      let suffix = pattern.substring(start=1)
      if path.ends_with(suffix) {
        return true
      }
    } else {
      // Exact or prefix match
      if path == pattern || path.starts_with("\{pattern}/") ||
         path.ends_with("/\{pattern}") || path.contains("/\{pattern}/") {
        return true
      }
    }
  }
  false
}

// File system helpers using @fs module
fn read_file_sync(path : String) -> Result[String, String] {
  try {
    Ok(@fs.read_file_to_string(path))
  } catch {
    e => Err(e.to_string())
  }
}

fn write_file_sync(path : String, content : String) -> Unit {
  try {
    @fs.write_string_to_file(path, content)
  } catch {
    _ => ()
  }
}

fn list_dir_sync(path : String) -> Array[String] {
  try {
    @fs.read_dir(path)
  } catch {
    _ => []
  }
}

fn is_dir_sync(path : String) -> Bool {
  try {
    @fs.is_dir(path)
  } catch {
    _ => false
  }
}

fn copy_to_clipboard(_content : String) -> Unit {
  // No clipboard support in MoonBit stdlib yet
  // Output goes to stdout for piping
  ()
}
