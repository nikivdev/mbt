///|
/// zed-open - Open paths in Zed with smart fuzzy resolution.
///
/// Usage:
///   zed-open [path|query ...]
///   zed-open --root <path> [path|query ...]
///   zed-open --multi [path|query ...]
///   zed-open code <query...>
///   zed-open -h | --help
///
/// Behavior:
/// - If a path exists, open it directly.
/// - If it does not exist, search using ripgrep file list and open the best match.
/// - If no match is found, create the path (touch file) and open it.

let program_name = "zed-open"
let zed_app_path = "/Applications/Zed.app"
let cache_dir = "~/.cache/zed-open"
let cache_ttl_seconds = 2

struct ParsedArgs {
  root : String
  queries : Array[String]
  show_help : Bool
  multi : Bool
}

async fn main {
  let args = @sys.get_cli_args()
  let cwd = get_cwd()
  let parsed = parse_args(args, cwd)
  if parsed.show_help {
    print_usage()
    return
  }
  let queries = if !parsed.multi && parsed.queries.length() > 1 && parsed.queries[0] != "code" {
    let combined = combine_queries_if_needed(parsed.queries, cwd)
    if combined.length() > 0 {
      [combined]
    } else {
      parsed.queries
    }
  } else {
    parsed.queries
  }
  if queries.length() > 0 && queries[0] == "code" {
    let query = join_from(queries, 1)
    if trim_whitespace(query).length() == 0 {
      println("Usage: \{program_name} code <query...>")
      return
    }
    let root = normalize_root(parsed.root, cwd)
    let matched = find_best_code_match(root, query)
    match matched {
      Some(path) => {
        let open_args : Array[String] = ["-a", zed_app_path, path]
        let result = run_exec("open", open_args, cwd)
        if result.exit_code != 0 && result.stderr.length() > 0 {
          println(result.stderr)
        }
      }
      None => {
        println("No code matches found.")
      }
    }
    return
  }
  if queries.length() == 0 {
    let open_args : Array[String] = ["-a", zed_app_path, cwd]
    let _ = run_exec("open", open_args, cwd)
    return
  }

  let root = normalize_root(parsed.root, cwd)
  let file_list = list_files(root)

  let resolved : Array[String] = []
  let mut any_env = false

  for query in queries {
    if query.length() == 0 {
      continue
    }
    let path = resolve_query(query, root, cwd, file_list)
    if is_env_path(path) {
      any_env = true
    }
    resolved.push(path)
  }

  if resolved.length() == 0 {
    let open_args : Array[String] = ["-a", zed_app_path, cwd]
    let _ = run_exec("open", open_args, cwd)
    return
  }

  if any_env {
    let _ = run_shell("open -g 'lin://stream?stop=true' && sleep 0.2", cwd)
  }

  let open_args : Array[String] = ["-a", zed_app_path]
  for path in resolved {
    open_args.push(path)
  }
  let result = run_exec("open", open_args, cwd)
  if result.exit_code != 0 && result.stderr.length() > 0 {
    println(result.stderr)
  }
}

fn print_usage() -> Unit {
  println("\{program_name} - smart Zed opener")
  println("")
  println("Usage:")
  println("  \{program_name} [path|query ...]")
  println("  \{program_name} --root <path> [path|query ...]")
  println("  \{program_name} --multi [path|query ...]")
  println("  \{program_name} code <query...>")
  println("  \{program_name} -h | --help")
}

fn parse_args(args : Array[String], cwd : String) -> ParsedArgs {
  let mut root = cwd
  let queries : Array[String] = []
  let mut show_help = false
  let mut multi = false
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--help" || arg == "-h" {
      show_help = true
    } else if arg == "--multi" {
      multi = true
    } else if arg == "--root" || arg == "-r" {
      i += 1
      if i < args.length() {
        root = args[i]
      }
    } else {
      queries.push(arg)
    }
    i += 1
  }
  ParsedArgs::{ root, queries, show_help, multi }
}

fn resolve_query(query : String, root : String, cwd : String, file_list : Array[String]) -> String {
  let normalized = trim_whitespace(query)
  let expanded = expand_path(normalized)
  let full = if expanded.has_prefix("/") {
    expanded
  } else {
    join_paths(cwd, expanded)
  }

  if @fs.path_exists(full) {
    return full
  }

  let best = find_best_match(normalized, file_list)
  match best {
    Some(path) => {
      if path.has_prefix("/") {
        path
      } else {
        join_paths(root, path)
      }
    }
    None => {
      ensure_parent_dir(full)
      touch_file(full)
      full
    }
  }
}

fn join_from(items : Array[String], start : Int) -> String {
  let parts : Array[String] = []
  let mut i = start
  while i < items.length() {
    parts.push(items[i])
    i += 1
  }
  parts.join(" ")
}

fn combine_queries_if_needed(queries : Array[String], cwd : String) -> String {
  let mut i = 0
  while i < queries.length() {
    let q = queries[i]
    let expanded = expand_path(q)
    let full = if expanded.has_prefix("/") {
      expanded
    } else {
      join_paths(cwd, expanded)
    }
    if @fs.path_exists(full) {
      return ""
    }
    i += 1
  }
  queries.join(" ")
}

async fn find_best_code_match(root : String, query : String) -> String? raise {
  let matches = search_code_matches(root, query)
  if matches.length() == 0 {
    return None
  }
  let mut best_score = -1
  let mut best_path : String? = None
  let mut i = 0
  while i < matches.length() {
    let item = matches[i]
    if item.score > best_score {
      best_score = item.score
      best_path = Some(item.path)
    } else if item.score == best_score {
      if best_path is Some(prev) {
        if item.path.length() < prev.length() {
          best_path = Some(item.path)
        }
      }
    }
    i += 1
  }
  match best_path {
    Some(path) => {
      if path.has_prefix("/") {
        Some(path)
      } else {
        Some(join_paths(root, path))
      }
    }
    None => None
  }
}

struct CodeMatch {
  path : String
  score : Int
}

async fn search_code_matches(root : String, query : String) -> Array[CodeMatch] raise {
  let cached = read_cached_code_matches(root, query)
  if cached.length() > 0 {
    return cached
  }

  let args : Array[String] = []
  args.push("-c")
  args.push("-F")
  args.push("--no-heading")
  args.push("--hidden")
  args.push("--glob")
  args.push("!**/.git/**")
  args.push("--glob")
  args.push("!**/node_modules/**")
  args.push("--glob")
  args.push("!**/_build/**")
  args.push("--glob")
  args.push("!**/target/**")
  args.push("--glob")
  args.push("!**/.ai/**")
  args.push("--glob")
  args.push("!**/.claude/**")
  args.push("--glob")
  args.push("!**/.codex/**")
  args.push(query)
  args.push(".")

  let result = run_exec("rg", args, root)
  if result.exit_code != 0 {
    return []
  }

  let results : Array[CodeMatch] = []
  for line_view in result.stdout.split("\n") {
    let line = trim_whitespace(line_view.to_string())
    if line.length() == 0 {
      continue
    }
    let idx = last_index_of_char(line, ':')
    if idx < 0 {
      continue
    }
    let path = substring(line, 0, idx)
    let count_text = substring(line, idx + 1, line.length())
    let count = parse_int(trim_whitespace(count_text))
    if count <= 0 {
      continue
    }
    let mut score = count * 20
    let depth = count_char(path, '/')
    score -= depth * 3
    if is_root_path(path) {
      score += 50
    }
    results.push(CodeMatch::{ path, score })
  }

  write_cached_code_matches(root, query, results)
  results
}


fn is_env_path(path : String) -> Bool {
  let base = basename(path)
  base.has_prefix(".env")
}

fn find_best_match(query : String, file_list : Array[String]) -> String? {
  if query.length() == 0 {
    return None
  }
  let q = query.to_lower()
  let mut best_score = -1
  let mut best_path : String? = None
  let mut root_best_score = -1
  let mut root_best_path : String? = None

  for path in file_list {
    let score = score_match(q, path)
    if score > 0 && is_root_path(path) {
      if score > root_best_score {
        root_best_score = score
        root_best_path = Some(path)
      } else if score == root_best_score {
        if root_best_path is Some(prev) {
          if path.length() < prev.length() {
            root_best_path = Some(path)
          }
        }
      }
      continue
    }
    if score > best_score {
      best_score = score
      best_path = Some(path)
    } else if score == best_score {
      if best_path is Some(prev) {
        if path.length() < prev.length() {
          best_path = Some(path)
        }
      }
    }
  }

  if root_best_score > 0 {
    return root_best_path
  }
  if best_score <= 0 {
    None
  } else {
    best_path
  }
}

fn score_match(query : String, path : String) -> Int {
  let p = path.to_lower()
  let base = basename(p)
  let mut score = 0

  if p == query {
    score += 1000
  }
  if base == query {
    score += 900
  }
  if base.has_prefix(query) {
    score += 400
  }
  if p.has_prefix(query) {
    score += 300
  }
  if base.contains(query) {
    score += 250
  }
  if p.contains(query) {
    score += 150
  }
  if is_subsequence(query, base) {
    score += 100
  } else if is_subsequence(query, p) {
    score += 50
  }

  let tokens = split_tokens(query)
  let mut token_hits = 0
  for token in tokens {
    if token.length() == 0 {
      continue
    }
    if base.contains(token) {
      token_hits += 1
    } else if p.contains(token) {
      token_hits += 1
    }
  }
  score += token_hits * 40

  let len_diff = if p.length() > query.length() {
    p.length() - query.length()
  } else {
    query.length() - p.length()
  }
  let bonus = 60 - len_diff
  if bonus > 0 {
    score += bonus
  }

  let depth = count_char(p, '/')
  score -= depth * 3

  score
}

fn split_tokens(text : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut buf = StringBuilder::new()
  let mut buf_len = 0
  for ch in text {
    if is_token_delim(ch) {
      if buf_len > 0 {
        tokens.push(buf.to_string())
        buf = StringBuilder::new()
        buf_len = 0
      }
    } else {
      buf.write_char(ch)
      buf_len += 1
    }
  }
  if buf_len > 0 {
    tokens.push(buf.to_string())
  }
  tokens
}

fn is_token_delim(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '/' || ch == '\\' || ch == '_' || ch == '-' || ch == '.'
}

fn is_subsequence(query : String, text : String) -> Bool {
  if query.length() == 0 {
    return true
  }
  let mut qi = 0
  for ch in text {
    if qi >= query.length() {
      break
    }
    if ch == char_at(query, qi) {
      qi += 1
    }
  }
  qi >= query.length()
}

fn count_char(text : String, ch : Char) -> Int {
  let mut count = 0
  for c in text {
    if c == ch {
      count += 1
    }
  }
  count
}

fn is_root_path(path : String) -> Bool {
  count_char(path, '/') == 0
}

fn is_git_repo(root : String) -> Bool {
  let git_dir = join_paths(root, ".git")
  try {
    @fs.is_dir(git_dir)
  } catch {
    _ => false
  }
}

async fn git_list_files(root : String) -> Array[String] raise {
  let args : Array[String] = []
  args.push("-C")
  args.push(root)
  args.push("ls-files")
  args.push("-co")
  args.push("--exclude-standard")
  let result = run_exec("git", args, root)
  if result.exit_code != 0 {
    return rg_list_files(root)
  }
  parse_lines(result.stdout)
}

async fn rg_list_files(root : String) -> Array[String] raise {
  let cmd =
    "rg --files --hidden " +
    "--glob '!**/.git/**' " +
    "--glob '!**/node_modules/**' " +
    "--glob '!**/_build/**' " +
    "--glob '!**/target/**' " +
    "--glob '!**/.ai/**' " +
    "--glob '!**/.claude/**' " +
    "--glob '!**/.codex/**'"
  let result = run_shell(cmd, root)
  if result.exit_code != 0 {
    return []
  }
  parse_lines(result.stdout)
}

fn parse_lines(text : String) -> Array[String] {
  let lines = text.split("\n")
  let files : Array[String] = []
  for line in lines {
    let trimmed = trim_whitespace(line.to_string())
    if trimmed.length() > 0 {
      files.push(trimmed)
    }
  }
  files
}

fn cache_key(root : String) -> String {
  let normalized = root.replace(old="/", new="_").replace(old=":", new="_")
  if normalized.length() == 0 {
    "root"
  } else {
    normalized
  }
}

fn cache_paths(root : String) -> (String, String) {
  let base = expand_path(cache_dir)
  let key = cache_key(root)
  let list_path = join_paths(base, key + ".list")
  let stamp_path = join_paths(base, key + ".stamp")
  (list_path, stamp_path)
}

fn code_cache_paths(root : String, query : String) -> (String, String) {
  let base = expand_path(cache_dir)
  let key = cache_key(root) + ".code." + hash_query(query)
  let list_path = join_paths(base, key + ".list")
  let stamp_path = join_paths(base, key + ".stamp")
  (list_path, stamp_path)
}

async fn read_cached_files(root : String) -> Array[String] raise {
  let (list_path, stamp_path) = cache_paths(root)
  if !path_exists(list_path) || !path_exists(stamp_path) {
    return []
  }
  let now = current_epoch_seconds()
  let stamp_text = match read_text_file(stamp_path) {
    Some(text) => trim_whitespace(text)
    None => ""
  }
  if stamp_text.length() == 0 {
    return []
  }
  let stamp = parse_int(stamp_text)
  if stamp < 0 {
    return []
  }
  if now - stamp > cache_ttl_seconds {
    return []
  }
  match read_text_file(list_path) {
    Some(text) => parse_lines(text)
    None => []
  }
}

async fn read_cached_code_matches(root : String, query : String) -> Array[CodeMatch] raise {
  let (list_path, stamp_path) = code_cache_paths(root, query)
  if !path_exists(list_path) || !path_exists(stamp_path) {
    return []
  }
  let now = current_epoch_seconds()
  let stamp_text = match read_text_file(stamp_path) {
    Some(text) => trim_whitespace(text)
    None => ""
  }
  if stamp_text.length() == 0 {
    return []
  }
  let stamp = parse_int(stamp_text)
  if stamp < 0 {
    return []
  }
  if now - stamp > cache_ttl_seconds {
    return []
  }
  match read_text_file(list_path) {
    Some(text) => parse_code_matches(text)
    None => []
  }
}

async fn write_cached_code_matches(root : String, query : String, matches : Array[CodeMatch]) -> Unit raise {
  let (list_path, stamp_path) = code_cache_paths(root, query)
  let dir = dirname(list_path)
  let _ = ensure_dir(dir)
  let content = serialize_code_matches(matches)
  let _ = write_text_file(list_path, content)
  let now = current_epoch_seconds()
  let _ = write_text_file(stamp_path, now.to_string())
}

async fn write_cached_files(root : String, files : Array[String]) -> Unit raise {
  let (list_path, stamp_path) = cache_paths(root)
  let dir = dirname(list_path)
  let _ = ensure_dir(dir)
  let content = files.join("\n") + "\n"
  let _ = write_text_file(list_path, content)
  let now = current_epoch_seconds()
  let _ = write_text_file(stamp_path, now.to_string())
}

async fn current_epoch_seconds() -> Int raise {
  let result = run_shell("date +%s", ".")
  let text = trim_whitespace(result.stdout)
  parse_int(text)
}

fn parse_int(text : String) -> Int {
  let mut value = 0
  let mut any = false
  for c in text {
    if c >= '0' && c <= '9' {
      value = value * 10 + (c.to_int() - '0'.to_int())
      any = true
    } else {
      break
    }
  }
  if any { value } else { -1 }
}

fn hash_query(text : String) -> String {
  let mut hash = 0
  for c in text {
    hash = (hash * 131 + c.to_int()) % 2147483647
  }
  hash.to_string()
}

fn serialize_code_matches(matches : Array[CodeMatch]) -> String {
  let lines : Array[String] = []
  for item in matches {
    lines.push(item.path + "\t" + item.score.to_string())
  }
  lines.join("\n") + "\n"
}

fn parse_code_matches(text : String) -> Array[CodeMatch] {
  let results : Array[CodeMatch] = []
  for line_view in text.split("\n") {
    let line = trim_whitespace(line_view.to_string())
    if line.length() == 0 {
      continue
    }
    let idx = index_of_char(line, '\t')
    if idx < 0 {
      continue
    }
    let path = substring(line, 0, idx)
    let score_text = substring(line, idx + 1, line.length())
    let score = parse_int(trim_whitespace(score_text))
    if score <= 0 {
      continue
    }
    results.push(CodeMatch::{ path, score })
  }
  results
}

fn index_of_char(text : String, ch : Char) -> Int {
  let mut i = 0
  for c in text {
    if c == ch {
      return i
    }
    i += 1
  }
  -1
}


async fn list_files(root : String) -> Array[String] raise {
  let cached = read_cached_files(root)
  if cached.length() > 0 {
    return cached
  }

  let files = if is_git_repo(root) {
    git_list_files(root)
  } else {
    rg_list_files(root)
  }

  write_cached_files(root, files)
  files
}

fn ensure_parent_dir(path : String) -> Unit {
  let dir = dirname(path)
  if dir == "." || dir.length() == 0 {
    return
  }
  let parts = dir.split("/")
  let mut current = ""
  let mut is_abs = dir.has_prefix("/")
  for part_view in parts {
    let part = part_view.to_string()
    if part.length() == 0 {
      continue
    }
    if current.length() == 0 && is_abs {
      current = "/" + part
      is_abs = false
    } else if current.length() == 0 {
      current = part
    } else {
      current = current + "/" + part
    }
    let exists = try { @fs.is_dir(current) } catch { _ => false }
    if !exists {
      try {
        @fs.create_dir(current)
      } catch {
        _ => ()
      }
    }
  }
}

fn touch_file(path : String) -> Unit {
  let exists = @fs.path_exists(path)
  if exists {
    return
  }
  try {
    @fs.write_string_to_file(path, "")
  } catch {
    _ => ()
  }
}

fn basename(path : String) -> String {
  let idx = last_index_of_char(path, '/')
  if idx < 0 {
    path
  } else {
    string_from(path, idx + 1)
  }
}

fn dirname(path : String) -> String {
  let idx = last_index_of_char(path, '/')
  if idx <= 0 {
    "."
  } else {
    string_until(path, idx)
  }
}

fn last_index_of_char(s : String, ch : Char) -> Int {
  let mut last = -1
  for i, c in s {
    if c == ch {
      last = i
    }
  }
  last
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

fn escape_single_quotes(value : String) -> String {
  value.replace(old="'", new="'\\''")
}

fn shell_quote(value : String) -> String {
  "'" + escape_single_quotes(value) + "'"
}

async fn ensure_dir(path : String) -> Bool raise {
  let cmd = "mkdir -p " + shell_quote(path)
  let result = run_shell(cmd, ".")
  result.exit_code == 0
}

fn path_exists(path : String) -> Bool {
  @fs.path_exists(path)
}

fn read_text_file(path : String) -> String? {
  try {
    let content = @fs.read_file_to_string(path)
    Some(content)
  } catch {
    _ => None
  }
}

fn write_text_file(path : String, content : String) -> Bool {
  try {
    @fs.write_string_to_file(path, content)
    true
  } catch {
    _ => false
  }
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

fn get_cwd() -> String {
  match @sys.get_env_var("PWD") {
    Some(path) => path
    None => "."
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
