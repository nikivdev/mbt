///|
/// Clean - Repository cleanup agent
///
/// Detects and removes cruft from repositories:
/// - Build artifacts (dist, out, _build, .next, etc.)
/// - Node modules and package caches
/// - Log files and temp files
/// - Old backups and duplicates

///|
async fn main raise {
  let args = @sys.get_cli_args()

  // Parse arguments
  let mut path = "."
  let mut dry_run = true
  let mut verbose = false
  let mut min_size = 0L
  let mut show_help = false
  let mut i = 1

  while i < args.length() {
    let arg = args[i]
    if arg == "--help" || arg == "-h" {
      show_help = true
    } else if arg == "--delete" || arg == "-d" {
      dry_run = false
    } else if arg == "--verbose" || arg == "-v" {
      verbose = true
    } else if arg == "--min-size" {
      if i + 1 < args.length() {
        i += 1
        min_size = parse_size(args[i])
      }
    } else if not(arg.has_prefix("-")) {
      path = arg
    }
    i += 1
  }

  if show_help {
    print_help()
    return
  }

  // Resolve path
  let root = if path.has_prefix("/") {
    path
  } else {
    let cwd = get_cwd()
    join_path(cwd, path)
  }

  println("Scanning: " + root)
  println("")

  // Configure and run scan
  let config = @cleaner.Config::new(root, min_size)
  let result = @cleaner.scan(config)

  // Print results
  if result.items.is_empty() {
    println("No cruft found!")
    return
  }

  // Group by category
  let by_category : Map[String, Array[@cleaner.CleanItem]] = {}
  for item in result.items {
    let key = item.category.to_string()
    match by_category.get(key) {
      Some(arr) => arr.push(item)
      None => by_category.set(key, [item])
    }
  }

  // Print summary header
  println("Found " + result.items.length().to_string() + " items to clean (" + @cleaner.format_size(result.total_size) + " total)")
  println("")

  // Print by category
  for entry in by_category {
    let (category, items) = entry
    let cat_size = items.fold(init=0L, fn(acc, item) { acc + item.size_bytes })
    println(to_upper(category) + " (" + items.length().to_string() + " items, " + @cleaner.format_size(cat_size) + ")")
    println(repeat_str("-", 50))

    for item in items {
      let size_str = @cleaner.format_size(item.size_bytes)
      let icon = item.category.icon()
      let rel_path = get_relative_path(item.path, root)
      println("  " + icon + " " + rel_path + " (" + size_str + ")")
      if verbose {
        println("      " + item.reason)
      }
    }
    println("")
  }

  // Print errors if any
  if not(result.errors.is_empty()) {
    println("ERRORS:")
    for error in result.errors {
      println("  " + error)
    }
    println("")
  }

  // Perform cleanup if not dry run
  if dry_run {
    println(repeat_str("-", 50))
    println("This was a dry run. To actually delete, run with --delete")
  } else {
    println("Cleaning...")
    let mut cleaned = 0
    let mut cleaned_size = 0L

    for item in result.items {
      let success = try {
        if item.is_dir {
          remove_dir_recursive(item.path)
        } else {
          @fs.remove_file(item.path)
        }
        true
      } catch {
        error => {
          println("  Failed to remove " + item.path + ": " + error.to_string())
          false
        }
      }

      if success {
        cleaned += 1
        cleaned_size = cleaned_size + item.size_bytes
        println("  Removed: " + item.path)
      }
    }

    println("")
    println("Cleaned " + cleaned.to_string() + " items (" + @cleaner.format_size(cleaned_size) + ")")
  }
}

///|
fn print_help() -> Unit {
  println("clean - Repository cleanup agent")
  println("")
  println("USAGE:")
  println("  clean [OPTIONS] [PATH]")
  println("")
  println("ARGUMENTS:")
  println("  PATH          Directory to scan (default: current directory)")
  println("")
  println("OPTIONS:")
  println("  -h, --help      Show this help message")
  println("  -d, --delete    Actually delete files (default is dry run)")
  println("  -v, --verbose   Show detailed reasons for each item")
  println("  --min-size N    Only show items larger than N bytes (supports K, M, G suffixes)")
  println("")
  println("DETECTED CRUFT:")
  println("  - Build artifacts: _build, dist, out, .next, build, target")
  println("  - Package dirs: node_modules, vendor")
  println("  - Cache dirs: .cache, .turbo, .mooncakes, .bun")
  println("  - Log files: *.log")
  println("  - Temp files: *.tmp, *.bak, *.swp, .DS_Store")
  println("  - Old backups: *-old, *-backup, *-past")
  println("")
  println("EXAMPLES:")
  println("  clean                     # Dry run in current directory")
  println("  clean ~/code/myproject    # Scan specific directory")
  println("  clean --delete            # Actually remove cruft")
  println("  clean --min-size 1M       # Only show items > 1MB")
}

///|
fn parse_size(s : String) -> Int64 {
  let s = to_upper(s)
  if s.has_suffix("G") || s.has_suffix("GB") {
    let end_pos = s.length() - (if s.has_suffix("GB") { 2 } else { 1 })
    let num = s.substring(end=end_pos)
    parse_int_or_zero(num) * 1024L * 1024L * 1024L
  } else if s.has_suffix("M") || s.has_suffix("MB") {
    let end_pos = s.length() - (if s.has_suffix("MB") { 2 } else { 1 })
    let num = s.substring(end=end_pos)
    parse_int_or_zero(num) * 1024L * 1024L
  } else if s.has_suffix("K") || s.has_suffix("KB") {
    let end_pos = s.length() - (if s.has_suffix("KB") { 2 } else { 1 })
    let num = s.substring(end=end_pos)
    parse_int_or_zero(num) * 1024L
  } else {
    parse_int_or_zero(s)
  }
}

///|
fn parse_int_or_zero(s : String) -> Int64 {
  let mut result = 0L
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10L + (c.to_int() - 48).to_int64()
    }
  }
  result
}

///|
fn get_relative_path(full_path : String, root : String) -> String {
  if full_path.has_prefix(root) {
    let rel = full_path.substring(start=root.length())
    if rel.has_prefix("/") {
      rel.substring(start=1)
    } else if rel.is_empty() {
      "."
    } else {
      rel
    }
  } else {
    full_path
  }
}

///|
fn remove_dir_recursive(path : String) -> Unit raise {
  let entries = @fs.read_dir(path)
  for name in entries {
    let full_path = join_path(path, name)
    if is_dir(full_path) {
      remove_dir_recursive(full_path)
    } else {
      @fs.remove_file(full_path)
    }
  }
  @fs.remove_dir(path)
}

///|
fn to_upper(s : String) -> String {
  let chars = []
  for c in s {
    if c >= 'a' && c <= 'z' {
      chars.push(Char::from_int(c.to_int() - 32))
    } else {
      chars.push(c)
    }
  }
  String::from_array(chars)
}

///|
fn repeat_str(s : String, n : Int) -> String {
  let result = StringBuilder::new()
  for _ in 0..<n {
    result.write_string(s)
  }
  result.to_string()
}

///|
fn get_cwd() -> String {
  match @sys.get_env_var("PWD") {
    Some(path) => path
    None => "."
  }
}

///|
fn is_dir(path : String) -> Bool {
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
