///|
/// Category of cruft detected
pub enum Category {
  BuildArtifact    // _build, dist, out, .next, build
  NodeModules      // node_modules
  PackageCache     // .mooncakes, .bun, .npm, .pnpm-store
  LogFile          // *.log
  TempFile         // *.tmp, *.bak, *.swp
  CacheDir         // .cache, .turbo, .parcel-cache
  OldBackup        // *-old, *-backup, *-past, past-*
  GeneratedFile    // *.generated.*, __generated__
  LockFile         // duplicate lock files in subdirs
  Symlink          // broken or redundant symlinks
  LargeMedia       // large media files that shouldn't be in repo
  Other
}

///|
/// A detected item that could be cleaned
pub struct CleanItem {
  path : String
  category : Category
  size_bytes : Int64
  is_dir : Bool
  reason : String
}

///|
/// Configuration for the scanner
pub struct Config {
  /// Root directory to scan
  root : String
  /// Patterns to always ignore (never suggest cleaning)
  ignore_patterns : Array[String]
  /// Additional patterns to detect as cruft
  extra_patterns : Array[String]
  /// Whether to follow symlinks
  follow_symlinks : Bool
  /// Max depth to scan (-1 for unlimited)
  max_depth : Int
  /// Minimum file size to report (bytes)
  min_size : Int64
}

///|
pub fn Config::default(root : String) -> Config {
  Config::{
    root,
    ignore_patterns: [],
    extra_patterns: [],
    follow_symlinks: false,
    max_depth: -1,
    min_size: 0L,
  }
}

///|
pub fn Config::new(root : String, min_size : Int64) -> Config {
  Config::{
    root,
    ignore_patterns: [],
    extra_patterns: [],
    follow_symlinks: false,
    max_depth: -1,
    min_size,
  }
}

///|
/// Result of a scan
pub struct ScanResult {
  items : Array[CleanItem]
  mut total_size : Int64
  scan_time_ms : Int
  errors : Array[String]
}

///|
pub fn ScanResult::new() -> ScanResult {
  ScanResult::{
    items: [],
    total_size: 0L,
    scan_time_ms: 0,
    errors: [],
  }
}

///|
/// Format bytes as human readable string
pub fn format_size(bytes : Int64) -> String {
  if bytes < 1024L {
    bytes.to_string() + " B"
  } else if bytes < 1024L * 1024L {
    let kb = bytes.to_double() / 1024.0
    if kb < 10.0 {
      round_one_decimal(kb) + " KB"
    } else {
      kb.to_int().to_string() + " KB"
    }
  } else if bytes < 1024L * 1024L * 1024L {
    let mb = bytes.to_double() / (1024.0 * 1024.0)
    if mb < 10.0 {
      round_one_decimal(mb) + " MB"
    } else {
      mb.to_int().to_string() + " MB"
    }
  } else {
    let gb = bytes.to_double() / (1024.0 * 1024.0 * 1024.0)
    round_one_decimal(gb) + " GB"
  }
}

///|
fn round_one_decimal(n : Double) -> String {
  let scaled = (n * 10.0).to_int()
  let whole = scaled / 10
  let frac = scaled % 10
  whole.to_string() + "." + frac.to_string()
}

///|
pub fn Category::to_string(self : Category) -> String {
  match self {
    BuildArtifact => "build"
    NodeModules => "node_modules"
    PackageCache => "cache"
    LogFile => "log"
    TempFile => "temp"
    CacheDir => "cache"
    OldBackup => "backup"
    GeneratedFile => "generated"
    LockFile => "lockfile"
    Symlink => "symlink"
    LargeMedia => "media"
    Other => "other"
  }
}

///|
pub fn Category::icon(self : Category) -> String {
  match self {
    BuildArtifact => "📦"
    NodeModules => "📁"
    PackageCache => "💾"
    LogFile => "📄"
    TempFile => "🗑️"
    CacheDir => "🗃️"
    OldBackup => "📂"
    GeneratedFile => "⚙️"
    LockFile => "🔒"
    Symlink => "🔗"
    LargeMedia => "🎬"
    Other => "❓"
  }
}
