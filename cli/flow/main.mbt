///|
extern "C" fn exit_process(code : Int) -> Unit = "moonbit_flow_exit"
#borrow(input)
extern "C" fn run_command_palette_native(input : Bytes) -> Bytes = "moonbit_flow_fzf_select"
extern "C" fn read_line_native() -> Bytes = "moonbit_flow_read_line"

struct Command {
  name : String
  description : String
}

fn command_catalog() -> Array[Command] {
  let commands : Array[Command] = []
  commands.push({ name: "help", description: "Show this message" })
  commands.push({ name: "version", description: "Print the CLI version" })
  commands.push({ name: "greet", description: "Print a friendly greeting" })
  commands.push({ name: "fib", description: "Compute nth Fibonacci number" })
  commands
}

fn main {
  let args = @sys.get_cli_args()
  let program = "flow"
  let commands = command_catalog()
  if args.length() <= 1 {
    guard run_command_palette(program, commands) else {
      print_usage(program, commands)
      return
    }
    return
  }
  guard handle_command(program, args, commands) else {
    let command = args[1]
    println("\{program}: unknown command `\{command}`")
    println("run `\{program} help` to see available commands")
    exit_process(1)
  }
}

fn handle_command(program : String, args : Array[String], commands : Array[Command]) -> Bool {
  if args.length() <= 1 {
    return false
  }
  let command = args[1]
  if command == "help" || command == "--help" || command == "-h" {
    print_usage(program, commands)
    true
  } else if command == "version" || command == "--version" {
    print_version()
    true
  } else if command == "greet" {
    handle_greet(args)
    true
  } else if command == "fib" {
    handle_fib(program, args)
    true
  } else {
    false
  }
}

///|
fn run_command_palette(program : String, commands : Array[Command]) -> Bool {
  let input_bytes = build_palette_input(commands)
  let selection_bytes = run_command_palette_native(input_bytes)
  if selection_bytes.length() == 0 {
    return false
  }
  let selection = utf8_bytes_to_string(selection_bytes)
  let command_name = extract_command_name(selection)
  if command_name.length() == 0 {
    return false
  }

  let args : Array[String] = []
  args.push(program)
  args.push(command_name)
  if !handle_command(program, args, commands) {
    println("\{program}: unknown command `\{command_name}`")
    println("run `\{program} help` to see available commands")
    exit_process(1)
  }
  true
}

///|
fn build_palette_input(commands : Array[Command]) -> Bytes {
  let bytes : Array[Byte] = []
  let mut index = 0
  while index < commands.length() {
    let command = commands[index]
    let line = "\{command.name}\t\{command.description}"
    let encoded = string_to_utf8_bytes(line)
    let mut j = 0
    while j < encoded.length() {
      bytes.push(encoded[j])
      j = j + 1
    }
    bytes.push('\n'.to_int().to_byte())
    index = index + 1
  }
  Bytes::from_array(bytes)
}

///|
fn extract_command_name(selection : String) -> String {
  let chars : Array[Char] = []
  let mut index = 0
  while index < selection.length() {
    let code = selection[index].to_int()
    if code == '\t'.to_int() {
      break
    }
    chars.push(Int::unsafe_to_char(code))
    index = index + 1
  }
  String::from_array(chars)
}

///|
fn max_command_name_length(commands : Array[Command]) -> Int {
  let mut max_len = 0
  let mut index = 0
  while index < commands.length() {
    let name_len = commands[index].name.length()
    if name_len > max_len {
      max_len = name_len
    }
    index = index + 1
  }
  max_len
}

///|
fn pad_command_name(name : String, width : Int) -> String {
  let chars : Array[Char] = []
  let mut index = 0
  while index < name.length() {
    chars.push(Int::unsafe_to_char(name[index].to_int()))
    index = index + 1
  }
  let mut remaining = width - name.length()
  let space = Int::unsafe_to_char(' '.to_int())
  while remaining > 0 {
    chars.push(space)
    remaining = remaining - 1
  }
  String::from_array(chars)
}

///|
fn string_to_utf8_bytes(str : String) -> Bytes {
  let res : Array[Byte] = []
  let len = str.length()
  let mut i = 0
  while i < len {
    let mut c = str[i].to_int()
    if 0xD800 <= c && c <= 0xDBFF {
      c -= 0xD800
      i = i + 1
      let l = str[i].to_int() - 0xDC00
      c = (c << 10) + l + 0x10000
    }

    if c < 0x80 {
      res.push(c.to_byte())
    } else if c < 0x800 {
      res.push((0xc0 + (c >> 6)).to_byte())
      res.push((0x80 + (c & 0x3f)).to_byte())
    } else if c < 0x10000 {
      res.push((0xe0 + (c >> 12)).to_byte())
      res.push((0x80 + ((c >> 6) & 0x3f)).to_byte())
      res.push((0x80 + (c & 0x3f)).to_byte())
    } else {
      res.push((0xf0 + (c >> 18)).to_byte())
      res.push((0x80 + ((c >> 12) & 0x3f)).to_byte())
      res.push((0x80 + ((c >> 6) & 0x3f)).to_byte())
      res.push((0x80 + (c & 0x3f)).to_byte())
    }
    i = i + 1
  }
  Bytes::from_array(res)
}

///|
fn utf8_bytes_to_string(bytes : Bytes) -> String {
  let res : Array[Char] = []
  let len = bytes.length()
  let mut i = 0
  while i < len {
    let mut c = bytes[i].to_int()
    if c < 0x80 {
      res.push(Int::unsafe_to_char(c))
      i = i + 1
    } else if c < 0xE0 {
      if i + 1 >= len {
        break
      }
      c = ((c & 0x1F) << 6) | (bytes[i + 1].to_int() & 0x3F)
      res.push(Int::unsafe_to_char(c))
      i = i + 2
    } else if c < 0xF0 {
      if i + 2 >= len {
        break
      }
      c = ((c & 0x0F) << 12) |
        ((bytes[i + 1].to_int() & 0x3F) << 6) |
        (bytes[i + 2].to_int() & 0x3F)
      res.push(Int::unsafe_to_char(c))
      i = i + 3
    } else {
      if i + 3 >= len {
        break
      }
      c = ((c & 0x07) << 18) |
        ((bytes[i + 1].to_int() & 0x3F) << 12) |
        ((bytes[i + 2].to_int() & 0x3F) << 6) |
        (bytes[i + 3].to_int() & 0x3F)
      c -= 0x10000
      res.push(Int::unsafe_to_char((c >> 10) + 0xD800))
      res.push(Int::unsafe_to_char((c & 0x3FF) + 0xDC00))
      i = i + 4
    }
  }
  String::from_array(res)
}

///|
fn trim_whitespace(value : String) -> String {
  let len = value.length()
  if len == 0 {
    return value
  }

  let mut start = 0
  while start < len && is_whitespace(value[start].to_int()) {
    start = start + 1
  }

  let mut end = len
  while end > start && is_whitespace(value[end - 1].to_int()) {
    end = end - 1
  }

  let chars : Array[Char] = []
  let mut index = start
  while index < end {
    chars.push(Int::unsafe_to_char(value[index].to_int()))
    index = index + 1
  }
  String::from_array(chars)
}

///|
fn is_whitespace(code : Int) -> Bool {
  code == ' '.to_int() ||
    code == '\n'.to_int() ||
    code == '\r'.to_int() ||
    code == '\t'.to_int()
}

///|
fn print_usage(program : String, commands : Array[Command]) -> Unit {
  println("Usage: \{program} <command> [arguments]")
  println("")
  println("Commands:")

  let width = max_command_name_length(commands)
  let mut index = 0
  while index < commands.length() {
    let command = commands[index]
    let padded = pad_command_name(command.name, width)
    println("  \{padded}  \{command.description}")
    index = index + 1
  }

  println("")
  println("Run `\{program}` without arguments to open the interactive command palette.")
}

///|
fn print_version() -> Unit {
  println("flow 0.1.0")
}

///|
fn handle_greet(args : Array[String]) -> Unit {
  let name = if args.length() > 2 { args[2] } else { "friend" }
  println("Hello, \{name}!")
}

///|
fn handle_fib(program : String, args : Array[String]) -> Unit {
  let raw_input =
    if args.length() > 2 {
      args[2]
    } else {
      println("Enter n for fib:")
      let line = read_line_native()
      let captured = utf8_bytes_to_string(line)
      let trimmed = trim_whitespace(captured)
      if trimmed.length() == 0 {
        println("\{program}: fibonacci index must be provided")
        exit_process(1)
      }
      trimmed
    }
  let n = parse_integer_or_exit(program, raw_input)
  if n < 0 {
    println("\{program}: fibonacci index must be non-negative")
    exit_process(1)
  }
  let result = fib(n)
  println("fib(\{n}) = \{result}")
}

///|
fn parse_integer_or_exit(program : String, raw : String) -> Int {
  if raw.length() == 0 {
    println("\{program}: expected an integer but found empty input")
    exit_process(1)
  }
  let zero = '0'.to_int()
  let nine = '9'.to_int()
  let mut index = 0
  let mut negative = false
  if raw[0].to_int() == '-'.to_int() {
    negative = true
    index = 1
  }
  if index >= raw.length() {
    println("\{program}: expected digits after '-' in integer argument")
    exit_process(1)
  }
  let mut value = 0
  while index < raw.length() {
    let code = raw[index].to_int()
    if code < zero || code > nine {
      println("\{program}: not a valid integer: \{raw}")
      exit_process(1)
    }
    value = value * 10 + (code - zero)
    index = index + 1
  }
  if negative {
    -value
  } else {
    value
  }
}

///|
fn fib(n : Int) -> Int64 {
  let mut i = 0
  let mut a = 0L
  let mut b = 1L
  while i < n {
    let next = a + b
    a = b
    b = next
    i = i + 1
  }
  b
}
