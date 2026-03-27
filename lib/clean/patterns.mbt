///|
/// Default patterns for detecting cruft in repositories

///| Build artifact directories
pub let build_dirs : Array[String] = [
  "_build",
  "build",
  "dist",
  "out",
  ".next",
  ".nuxt",
  ".output",
  ".svelte-kit",
  ".vercel",
  ".netlify",
  "target",
  "bin",
  "obj",
  "__pycache__",
  ".pytest_cache",
  ".mypy_cache",
  ".ruff_cache",
  "coverage",
  ".nyc_output",
  ".expo",
]

///| Node modules and package directories
pub let package_dirs : Array[String] = [
  "node_modules",
  "bower_components",
  "jspm_packages",
  ".pnpm",
  "vendor",
]

///| Cache directories
pub let cache_dirs : Array[String] = [
  ".cache",
  ".turbo",
  ".parcel-cache",
  ".vite",
  ".rollup.cache",
  ".eslintcache",
  ".stylelintcache",
  ".prettiercache",
  ".mooncakes",
  ".moon",
  ".bun",
  ".npm",
  ".yarn",
  ".pnpm-store",
  ".gradle",
  ".m2",
  ".cargo",
  ".rustup",
  "__pycache__",
  ".tox",
  ".nox",
  ".hypothesis",
  ".pytest_cache",
]

///| Log file patterns
pub let log_patterns : Array[String] = [
  "*.log",
  "*.log.*",
  "npm-debug.log*",
  "yarn-debug.log*",
  "yarn-error.log*",
  "pnpm-debug.log*",
  ".pnpm-debug.log",
  "lerna-debug.log*",
]

///| Temporary file patterns
pub let temp_patterns : Array[String] = [
  "*.tmp",
  "*.temp",
  "*.bak",
  "*.backup",
  "*.swp",
  "*.swo",
  "*~",
  ".DS_Store",
  "Thumbs.db",
  "desktop.ini",
  "*.orig",
  "*.rej",
]

///| Old/backup directory patterns
pub let backup_patterns : Array[String] = [
  "*-old",
  "*-backup",
  "*-bak",
  "*-past",
  "past-*",
  "old-*",
  "backup-*",
  "*.old",
  "*_old",
  "*_backup",
  "*_bak",
]

///| Generated file patterns
pub let generated_patterns : Array[String] = [
  "*.generated.*",
  "__generated__",
  ".generated",
  "*.g.dart",
  "*.freezed.dart",
  "*.gr.dart",
  "generated",
]

///| Lock files that shouldn't be duplicated in subdirs
pub let lock_files : Array[String] = [
  "package-lock.json",
  "yarn.lock",
  "pnpm-lock.yaml",
  "bun.lock",
  "bun.lockb",
  "Cargo.lock",
  "Gemfile.lock",
  "poetry.lock",
  "composer.lock",
]

///| IDE and editor directories
pub let ide_dirs : Array[String] = [
  ".idea",
  ".vscode",
  "*.code-workspace",
  ".project",
  ".classpath",
  ".settings",
  "*.sublime-*",
]

///| Test output directories
pub let test_output_dirs : Array[String] = [
  "coverage",
  ".nyc_output",
  "test-results",
  "test-reports",
  "junit",
  "htmlcov",
  ".coverage",
]

///| Check if a name matches a pattern (simple glob matching)
pub fn matches_pattern(name : String, pattern : String) -> Bool {
  if pattern.has_prefix("*") && pattern.has_suffix("*") {
    // *foo* - contains
    let inner = substring_safe(pattern, 1, pattern.length() - 1)
    name.contains(inner)
  } else if pattern.has_prefix("*") {
    // *.log - ends with
    let suffix = substring_safe(pattern, 1, pattern.length())
    name.has_suffix(suffix)
  } else if pattern.has_suffix("*") {
    // foo* - starts with
    let prefix = substring_safe(pattern, 0, pattern.length() - 1)
    name.has_prefix(prefix)
  } else {
    // exact match
    name == pattern
  }
}

///| Safe substring extraction
fn substring_safe(s : String, start : Int, end : Int) -> String {
  let chars = []
  let mut i = 0
  for c in s {
    if i >= start && i < end {
      chars.push(c)
    }
    i += 1
  }
  String::from_array(chars)
}

///| Check if name matches any pattern in array
pub fn matches_any(name : String, patterns : Array[String]) -> Bool {
  for pattern in patterns {
    if matches_pattern(name, pattern) {
      return true
    }
  }
  false
}

///| Categorize a file/directory name
pub fn categorize(name : String, is_dir : Bool) -> Category? {
  // Check directories first
  if is_dir {
    if matches_any(name, build_dirs) {
      return Some(BuildArtifact)
    }
    if matches_any(name, package_dirs) {
      return Some(NodeModules)
    }
    if matches_any(name, cache_dirs) {
      return Some(PackageCache)
    }
    if matches_any(name, backup_patterns) {
      return Some(OldBackup)
    }
    if matches_any(name, test_output_dirs) {
      return Some(BuildArtifact)
    }
    if matches_any(name, generated_patterns) {
      return Some(GeneratedFile)
    }
  } else {
    // Files
    if matches_any(name, log_patterns) {
      return Some(LogFile)
    }
    if matches_any(name, temp_patterns) {
      return Some(TempFile)
    }
    if matches_any(name, backup_patterns) {
      return Some(OldBackup)
    }
    if matches_any(name, generated_patterns) {
      return Some(GeneratedFile)
    }
  }
  None
}

///| Get reason string for a category match
pub fn get_reason(_name : String, category : Category) -> String {
  match category {
    BuildArtifact => "Build output directory"
    NodeModules => "Package dependencies (can be reinstalled)"
    PackageCache => "Package manager cache"
    LogFile => "Log file"
    TempFile => "Temporary file"
    CacheDir => "Cache directory"
    OldBackup => "Old/backup file or directory"
    GeneratedFile => "Generated file"
    LockFile => "Duplicate lock file in subdirectory"
    Symlink => "Symlink"
    LargeMedia => "Large media file"
    Other => "Unknown cruft"
  }
}
