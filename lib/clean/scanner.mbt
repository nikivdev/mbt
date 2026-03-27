///|
/// Scanner for detecting cruft in repositories

///|
/// Scan a directory for cruft
pub async fn scan(config : Config) -> ScanResult {
  let result = ScanResult::new()
  let root = config.root

  // Check if root exists
  guard path_exists(root) else {
    result.errors.push("Root directory does not exist: " + root)
    return result
  }

  // Walk the tree
  scan_dir(root, config, result, 0)

  // Sort by size descending
  result.items.sort_by(fn(a, b) {
    if a.size_bytes > b.size_bytes { -1 }
    else if a.size_bytes < b.size_bytes { 1 }
    else { 0 }
  })

  result
}

///|
async fn scan_dir(
  path : String,
  config : Config,
  result : ScanResult,
  depth : Int,
) -> Unit {
  // Check max depth
  if config.max_depth >= 0 && depth > config.max_depth {
    return
  }

  // List directory contents
  let entries = try {
    @fs.read_dir(path)
  } catch {
    error => {
      result.errors.push("Error reading " + path + ": " + error.to_string())
      return
    }
  }

  for name in entries {
    let full_path = join_path(path, name)
    let is_dir = is_directory(full_path)

    // Skip ignored patterns
    if should_ignore(name, config.ignore_patterns) {
      continue
    }

    // Check if this is cruft
    match categorize(name, is_dir) {
      Some(category) => {
        // Don't descend into cruft dirs, just report them
        let size = measure_path_size(full_path, is_dir)

        // Skip if below minimum size
        if size >= config.min_size {
          result.items.push(CleanItem::{
            path: full_path,
            category,
            size_bytes: size,
            is_dir,
            reason: get_reason(name, category),
          })
          result.total_size = result.total_size + size
        }
      }
      None => {
        // Not cruft - if it's a directory, recurse into it
        if is_dir {
          scan_dir(full_path, config, result, depth + 1)
        }
      }
    }
  }
}

///|
fn should_ignore(name : String, patterns : Array[String]) -> Bool {
  // Always ignore .git
  if name == ".git" {
    return true
  }
  matches_any(name, patterns)
}

///|
fn get_file_size(path : String) -> Int64 {
  try {
    @fs.read_file_to_bytes(path).length().to_int64()
  } catch {
    _ => 0L
  }
}

///|
async fn measure_path_size(path : String, is_dir : Bool) -> Int64 {
  let command = if is_dir {
    "du -sk " + shell_quote(path) + " 2>/dev/null"
  } else {
    "stat -f%z " + shell_quote(path) + " 2>/dev/null || stat -c %s " +
    shell_quote(path) + " 2>/dev/null"
  }
  try {
    let (exit_code, stdout_data, _stderr_data) = @process.collect_output(
      "sh",
      ["-c", command],
      cwd=".",
    )
    if exit_code != 0 {
      return 0L
    }
    let text = trim_whitespace(stdout_data.text())
    if text.length() == 0 {
      return 0L
    }
    if is_dir {
      parse_int64_or_zero(first_field(text)) * 1024L
    } else {
      parse_int64_or_zero(text)
    }
  } catch {
    _ => 0L
  }
}

///|
fn path_exists(path : String) -> Bool {
  @fs.path_exists(path)
}

///|
fn is_directory(path : String) -> Bool {
  try {
    @fs.is_dir(path)
  } catch {
    _ => false
  }
}

///|
fn join_path(base : String, name : String) -> String {
  if base.has_suffix("/") {
    base + name
  } else {
    base + "/" + name
  }
}

///|
fn trim_whitespace(text : String) -> String {
  text.trim(chars=" \n\t\r").to_string()
}

///|
fn first_field(text : String) -> String {
  let out = StringBuilder::new()
  for c in text {
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      break
    }
    out.write_char(c)
  }
  out.to_string()
}

///|
fn parse_int64_or_zero(text : String) -> Int64 {
  let mut out = 0L
  for c in text {
    if c >= '0' && c <= '9' {
      out = out * 10L + (c.to_int() - 48).to_int64()
    }
  }
  out
}

///|
fn shell_quote(value : String) -> String {
  "'" + value.replace(old="'", new="'\\''") + "'"
}

///|
/// Check for duplicate lock files in subdirectories
pub fn find_duplicate_lockfiles(root : String) -> Array[CleanItem] {
  let items : Array[CleanItem] = []

  fn find_locks(path : String, depth : Int) -> Unit {
    if depth > 10 {
      return
    }

    let entries = try {
      @fs.read_dir(path)
    } catch {
      _ => return
    }

    for name in entries {
      let full_path = join_path(path, name)

      if is_directory(full_path) && name != ".git" && name != "node_modules" {
        // Check if this subdir has its own lock file
        for lock_name in lock_files {
          let lock_path = join_path(full_path, lock_name)
          if path_exists(lock_path) {
            let root_lock = join_path(root, lock_name)
            if path_exists(root_lock) && full_path != root {
              items.push(CleanItem::{
                path: lock_path,
                category: LockFile,
                size_bytes: get_file_size(lock_path),
                is_dir: false,
                reason: "Duplicate lock file (also exists at root)",
              })
            }
          }
        }
        find_locks(full_path, depth + 1)
      }
    }
  }

  find_locks(root, 0)
  items
}
