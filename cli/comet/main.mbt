///|
/// comet - save all open Comet browser tabs
///
/// Usage:
///   comet
///   comet close
///   comet -h | --help
///
/// Saves all open tabs to ~/data/comet-sessions/ as JSON

let program_name = "comet"
let program_version = "0.1.0"
let sessions_folder = "/Users/nikiv/data/comet-sessions"

struct Tab {
  title : String
  url : String
} derive(ToJson)

async fn main {
  let args = @sys.get_cli_args()
  if args.length() > 1 {
    let first = args[1]
    if first == "-h" || first == "--help" {
      print_usage()
      return
    }
    if first == "--version" || first == "-v" {
      println("\{program_name} \{program_version}")
      return
    }
    if first == "close" {
      close_tabs()
      return
    }
    if first == "undo" {
      undo_close()
      return
    }
  }
  save_tabs()
}

fn print_usage() -> Unit {
  println("\{program_name} - save all open Comet browser tabs")
  println("")
  println("Usage:")
  println("  \{program_name}          Save all tabs to JSON")
  println("  \{program_name} close    Close all tabs except first in each window")
  println("  \{program_name} undo     Reopen tabs from last saved session")
  println("  \{program_name} -h       Show this help")
}

async fn save_tabs() -> Unit raise {
  let tabs = get_comet_tabs()
  if tabs.length() == 0 {
    println("No tabs found in Comet")
    return
  }

  ensure_folder_exists(sessions_folder)
  let file_path = get_output_path()
  let json = tabs_to_json(tabs)
  write_file(file_path, json)
  println("Saved \{tabs.length()} tabs to \{file_path}")
}

async fn close_tabs() -> Unit raise {
  let script =
    #|osascript -e '
    #|tell application "Comet"
    #|    set closedCount to 0
    #|    set window_list to every window
    #|    repeat with the_window in window_list
    #|        set tab_list to every tab in the_window
    #|        set tabCount to count of tab_list
    #|        if tabCount > 1 then
    #|            repeat with i from tabCount to 2 by -1
    #|                close item i of tab_list
    #|                set closedCount to closedCount + 1
    #|            end repeat
    #|        end if
    #|    end repeat
    #|    return closedCount
    #|end tell
    #|'
  let result = run_shell(script, ".")
  if result.exit_code != 0 {
    println("Failed to close tabs")
    return
  }
  let count = result.stdout.trim().to_string()
  println("Closed \{count} tabs")
}

async fn undo_close() -> Unit raise {
  let find_result = run_shell(
    "ls -t '\{sessions_folder}' 2>/dev/null | head -1",
    ".",
  )
  let latest_file = find_result.stdout.trim().to_string()
  if latest_file.length() == 0 {
    println("No saved sessions found")
    return
  }

  let file_path = "\{sessions_folder}/\{latest_file}"
  let read_result = run_shell("cat '\{file_path}'", ".")
  if read_result.exit_code != 0 {
    println("Failed to read \{file_path}")
    return
  }

  let urls = parse_urls_from_json(read_result.stdout)
  if urls.length() == 0 {
    println("No URLs found in \{latest_file}")
    return
  }

  open_urls_in_comet(urls)
  println("Opened \{urls.length()} tabs from \{latest_file}")
}

fn parse_urls_from_json(json_str : String) -> Array[String] {
  let urls : Array[String] = []
  let parsed = try { @json.parse(json_str) } catch { _ => return urls }
  guard parsed is Array(items) else { return urls }
  for item in items {
    guard item is Object(obj) else { continue }
    match obj.get("url") {
      Some(String(url)) => urls.push(url)
      _ => ()
    }
  }
  urls
}

async fn open_urls_in_comet(urls : Array[String]) -> Unit raise {
  for url in urls {
    let escaped_url = url.replace(old="'", new="'\\''")
    let script = "osascript -e 'tell application \"Comet\" to open location \"" +
      escaped_url +
      "\"'"
    let _ = run_shell(script, ".")
  }
}

async fn get_comet_tabs() -> Array[Tab] raise {
  let script =
    #|osascript -e '
    #|set tabsText to ""
    #|tell application "Comet"
    #|    set window_list to every window
    #|    repeat with the_window in window_list
    #|        set tab_list to every tab in the_window
    #|        repeat with the_tab in tab_list
    #|            set the_url to the URL of the_tab
    #|            set the_title to the title of the_tab
    #|            set tabsText to tabsText & the_title & "|||" & the_url & "
    #|"
    #|        end repeat
    #|    end repeat
    #|end tell
    #|return tabsText
    #|'
  let result = run_shell(script, ".")
  if result.exit_code != 0 {
    return []
  }
  parse_tabs(result.stdout)
}

fn parse_tabs(output : String) -> Array[Tab] {
  let tabs : Array[Tab] = []
  for line_view in output.split("\n") {
    let line = line_view.to_string().trim().to_string()
    if line.length() == 0 {
      continue
    }
    let sep_idx = index_of_str(line, "|||")
    if sep_idx < 0 {
      continue
    }
    let title = substring(line, 0, sep_idx)
    let url = substring(line, sep_idx + 3, line.length())
    if url.length() > 0 {
      tabs.push(Tab::{ title, url })
    }
  }
  tabs
}

fn index_of_str(text : String, needle : String) -> Int {
  let text_len = string_length(text)
  let needle_len = string_length(needle)
  if needle_len == 0 || needle_len > text_len {
    return -1
  }
  let mut i = 0
  while i <= text_len - needle_len {
    let slice = substring(text, i, i + needle_len)
    if slice == needle {
      return i
    }
    i += 1
  }
  -1
}

fn string_length(s : String) -> Int {
  let mut count = 0
  for _ in s {
    count += 1
  }
  count
}

fn substring(text : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  for c in text {
    if i >= start && i < end {
      buf.write_char(c)
    }
    i += 1
  }
  buf.to_string()
}

fn tabs_to_json(tabs : Array[Tab]) -> String {
  let json_array : Json = Json::array(tabs.map(fn(tab) { tab.to_json() }))
  json_array.stringify()
}

async fn ensure_folder_exists(path : String) -> Unit raise {
  let _ = run_shell("mkdir -p '\{path}'", ".")
}

async fn get_output_path() -> String raise {
  let date_result = run_shell("date +%Y-%m-%d", ".")
  let date_str = date_result.stdout.trim().to_string()
  let base_name = "\{date_str}-comet-tabs"
  let base_path = "\{sessions_folder}/\{base_name}.json"

  let check = run_shell("test -f '\{base_path}' && echo exists || echo no", ".")
  if check.stdout.trim().to_string() != "exists" {
    return base_path
  }

  let mut num = 1
  while num < 1000 {
    let path = "\{sessions_folder}/\{base_name}-\{num}.json"
    let c = run_shell("test -f '\{path}' && echo exists || echo no", ".")
    if c.stdout.trim().to_string() != "exists" {
      return path
    }
    num += 1
  }
  base_path
}

async fn write_file(path : String, content : String) -> Unit raise {
  let escaped = content.replace(old="'", new="'\\''")
  let _ = run_shell("printf '%s' '\{escaped}' > '\{path}'", ".")
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
  CmdResult::{
    exit_code,
    stdout: stdout_data.text(),
    stderr: stderr_data.text(),
  }
}
