///|
/// lmstudio-test - quick LM Studio smoke tests for local models.
///
/// Usage:
///   lmstudio-test prompt <text...>
///   lmstudio-test fishy-tests
///   lmstudio-test env-tests
///   lmstudio-test env-agent-tests
///   lmstudio-test -h | --help

let default_model = "zai-org/glm-4.7-flash"
let default_port = 1234

struct FishyTestCase {
  name : String
  prompt : String
  expect : String
}

async fn main {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    print_usage()
    return
  }
  let cmd = args[1]
  if cmd == "-h" || cmd == "--help" {
    print_usage()
    return
  }

  if cmd == "prompt" {
    if args.length() < 3 {
      println("Missing prompt text")
      return
    }
    let prompt = join_args(args, 2)
    let (model, port) = resolve_model_port(None, None)
    let text = prompt_local_model(model, port, "You are a helpful assistant.", prompt)
    println(text)
    return
  }

  if cmd == "fishy-tests" {
    run_fishy_tests()
    return
  }
  if cmd == "env-tests" {
    run_env_tests()
    return
  }
  if cmd == "env-agent-tests" {
    run_env_agent_tests()
    return
  }

  print_usage()
}

fn print_usage() -> Unit {
  println("lmstudio-test - local LM Studio smoke tests")
  println("")
  println("Usage:")
  println("  lmstudio-test prompt <text...>")
  println("  lmstudio-test fishy-tests")
  println("  lmstudio-test env-tests")
  println("  lmstudio-test env-agent-tests")
  println("")
  println("Env overrides:")
  println("  LM_STUDIO_MODEL (default: \{default_model})")
  println("  LM_STUDIO_PORT  (default: 1234)")
  println("  LM_STUDIO_ALLOW_COT=1 (allow reasoning text)")
}

fn join_args(args : Array[String], start : Int) -> String {
  let parts : Array[String] = []
  let mut i = start
  while i < args.length() {
    parts.push(args[i])
    i += 1
  }
  parts.join(" ")
}

fn resolve_model_port(model_override : String?, port_override : Int?) -> (String, Int) {
  let mut model = model_override.unwrap_or("")
  if model.length() == 0 {
    match @sys.get_env_var("LM_STUDIO_MODEL") {
      Some(value) => model = value
      None => ()
    }
  }
  if model.length() == 0 {
    model = default_model
  }

  let mut port = port_override.unwrap_or(-1)
  if port <= 0 {
    match @sys.get_env_var("LM_STUDIO_PORT") {
      Some(value) => {
        port = try { @strconv.parse_int(value) } catch { _ => -1 }
      }
      None => ()
    }
  }
  if port <= 0 {
    port = default_port
  }
  (model, port)
}

async fn prompt_local_model(
  model_name : String,
  port : Int,
  system_prompt : String,
  user_prompt : String,
) -> String raise {
  let url = "http://localhost:\{port}/v1/chat/completions"
  let body : Json = {
    "model": model_name,
    "messages": Json::array([
      Json::object({ "role": "system", "content": system_prompt }),
      Json::object({ "role": "user", "content": user_prompt }),
    ]),
    "temperature": 0.1,
    "max_tokens": 512,
  }
  let headers = {
    "Content-Type": "application/json",
  }
  let (response, data) = @http.post(url, body, headers~)
  if response.code < 200 || response.code > 299 {
    return ""
  }
  let text_body = data.text()
  extract_chat_content(text_body)
}

fn extract_chat_content(text_body : String) -> String {
  let parsed = try { @json.parse(text_body) } catch { _ => return "" }
  match parsed {
    Object(obj) => {
      match obj.get("choices") {
        Some(Array(choices)) => {
          if choices.length() == 0 {
            return ""
          }
          match choices[0] {
            Object(choice) => {
              match choice.get("message") {
                Some(Object(msg)) =>
                  match msg.get("content") {
                    Some(String(content)) => content.trim().to_string()
                    _ => ""
                  }
                _ => ""
              }
            }
            _ => ""
          }
        }
        _ => ""
      }
    }
    _ => ""
  }
}

async fn run_fishy_tests() -> Unit raise {
  let tests : Array[FishyTestCase] = [
    FishyTestCase::{
      name: "wrap",
      prompt: "wrap zed-open for w",
      expect: "wrap",
    },
    FishyTestCase::{
      name: "set",
      prompt: "set -Ua fish_features no-query-term",
      expect: "set",
    },
    FishyTestCase::{
      name: "function",
      prompt: "make function gs that runs git status",
      expect: "function",
    },
  ]

  let system_prompt = build_fishy_system_prompt()

  let (model, port) = resolve_model_port(None, None)
  println("Model: \{model}  Port: \{port}")

  for case_ in tests {
    let response = prompt_local_model(model, port, system_prompt, case_.prompt)
    let parsed = extract_json_object(response)
    match parsed {
      None => {
        println("[FAIL] \{case_.name}: could not parse JSON")
        println("  raw: \{response}")
      }
      Some(json) => {
        let action = match json {
          Object(obj) => match obj.get("action") {
            Some(String(value)) => value
            _ => ""
          }
          _ => ""
        }
        if action == case_.expect {
          println("[PASS] \{case_.name}: action=\{action}")
        } else {
          println("[FAIL] \{case_.name}: action=\{action}")
        }
        println("  raw: \{response}")
      }
    }
  }
}

struct EnvTestCase {
  name : String
  prompt : String
  expect_keys : Array[String]
}

async fn run_env_tests() -> Unit raise {
  let tests : Array[EnvTestCase] = [
    EnvTestCase::{
      name: "aws",
      prompt: "env aws Access Key ID: test-access-key-id-123 Secret Access Key test-secret-access-key-456 Region: eu-central-1",
      expect_keys: ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_REGION"],
    },
    EnvTestCase::{
      name: "stream",
      prompt: "env STREAM_SERVER_HETZNER_HOST=u533855.your-storagebox.de STREAM_SERVER_HETZNER_USER=u533855 STREAM_SERVER_HETZNER_PATH=/backups/streams STREAM_SERVER_HETZNER_PORT=23",
      expect_keys: [
        "STREAM_SERVER_HETZNER_HOST",
        "STREAM_SERVER_HETZNER_USER",
        "STREAM_SERVER_HETZNER_PATH",
        "STREAM_SERVER_HETZNER_PORT",
      ],
    },
  ]

  let system_prompt = build_env_system_prompt()

  let (model, port) = resolve_model_port(None, None)
  println("Model: \{model}  Port: \{port}")

  for case_ in tests {
    let response = prompt_local_model(model, port, system_prompt, case_.prompt)
    let parsed = extract_json_object(response)
    match parsed {
      None => {
        println("[FAIL] \{case_.name}: could not parse JSON")
        println("  raw: \{response}")
      }
      Some(json) => {
        let keys = extract_env_keys(json)
        let missing = missing_keys(case_.expect_keys, keys)
        let missing_str = missing.join(", ")
        if missing.length() == 0 {
          println("[PASS] \{case_.name}")
        } else {
          println("[FAIL] \{case_.name}: missing \{missing_str}")
        }
        println("  raw: \{response}")
      }
    }
  }
}

struct EnvAgentTestCase {
  name : String
  prompt : String
}

async fn run_env_agent_tests() -> Unit raise {
  let tests : Array[EnvAgentTestCase] = [
    EnvAgentTestCase::{
      name: "aws",
      prompt: "env aws Access Key ID: test-access-key-id-123 Secret Access Key test-secret-access-key-456 Region: eu-central-1",
    },
    EnvAgentTestCase::{
      name: "stream",
      prompt: "env STREAM_SERVER_HETZNER_HOST=u533855.your-storagebox.de STREAM_SERVER_HETZNER_USER=u533855 STREAM_SERVER_HETZNER_PATH=/backups/streams STREAM_SERVER_HETZNER_PORT=23",
    },
  ]

  let system_prompt =
    "Use Flow env store to save env vars. Output a single bash command only. " +
    "Prefer: FLOW_ENV_BACKEND=local env-help save [--env <name>] [service] <raw text>. " +
    "If user already provides KEY=VALUE pairs, pass them through as-is. " +
    "If user mentions an env name, include --env <name>. " +
    "Do not echo secrets or add extra text."

  let (model, port) = resolve_model_port(None, None)
  println("Model: \{model}  Port: \{port}")

  for case_ in tests {
    let response = prompt_local_model(model, port, system_prompt, case_.prompt)
    let line = last_non_empty_line(response)
    let ok = contains_any(line, ["env-help save", "hive env", "f env set"])
    if ok {
      println("[PASS] \{case_.name}: \{line}")
    } else {
      println("[FAIL] \{case_.name}: \{line}")
    }
  }
}

fn extract_env_keys(json : Json) -> Array[String] {
  let out : Array[String] = []
  match json {
    Object(obj) => {
      match obj.get("items") {
        Some(Array(items)) => {
          for item in items {
            match item {
              Object(entry) => {
                match entry.get("key") {
                  Some(String(value)) => out.push(value)
                  _ => ()
                }
              }
              _ => ()
            }
          }
        }
        _ => ()
      }
    }
    _ => ()
  }
  out
}

fn missing_keys(expected : Array[String], got : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for key in expected {
    let mut found = false
    for got_key in got {
      if got_key == key {
        found = true
        break
      }
    }
    if !found {
      out.push(key)
    }
  }
  out
}

fn contains_any(text : String, needles : Array[String]) -> Bool {
  for needle in needles {
    if text.contains(needle) {
      return true
    }
  }
  false
}

fn last_non_empty_line(text : String) -> String {
  let lines : Array[String] = []
  for line_view in text.split("\n") {
    let line = trim_whitespace(line_view.to_string())
    if line.length() > 0 {
      lines.push(line)
    }
  }
  if lines.length() == 0 {
    ""
  } else {
    lines[lines.length() - 1]
  }
}

fn env_true(name : String) -> Bool {
  match @sys.get_env_var(name) {
    Some(value) => {
      let lower = value.to_lower()
      lower == "1" || lower == "true" || lower == "yes" || lower == "on"
    }
    None => false
  }
}

fn allow_cot() -> Bool {
  env_true("LM_STUDIO_ALLOW_COT")
}

fn build_fishy_system_prompt() -> String {
  let schema =
    "Schema: {\"action\":\"wrap|set|function|unknown\", " +
    "\"name\":\"\", \"command\":\"\", \"args\":[], " +
    "\"flags\":\"\", \"var\":\"\", \"values\":[], " +
    "\"body\":\"\", \"description\":\"\"}. " +
    "Use empty strings or empty arrays when a field is not needed."
  if allow_cot() {
    "You convert fish shell requests into JSON. " +
    "You may include reasoning, but you MUST include a final JSON object. " +
    "The last JSON object in your response will be parsed. " +
    schema
  } else {
    "You convert fish shell requests into JSON. Output ONLY JSON. " +
    "No markdown, no backticks, no extra text, no explanations. " +
    schema
  }
}

fn build_env_system_prompt() -> String {
  let schema =
    "Schema: {\"action\":\"env\",\"env\":\"\",\"items\":[{\"key\":\"\",\"value\":\"\"}]}. " +
    "Use empty env when not specified."
  if allow_cot() {
    "You extract env vars from user text. " +
    "You may include reasoning, but you MUST include a final JSON object. " +
    "The last JSON object in your response will be parsed. " +
    schema
  } else {
    "You extract env vars from user text. Output ONLY JSON. " +
    "No markdown, no backticks, no extra text. " +
    schema
  }
}

fn extract_json_object(text : String) -> Json? {
  let trimmed = trim_whitespace(text)
  match try_parse_json(trimmed) {
    Some(json) =>
      match json {
        Object(_) => return Some(json)
        _ => ()
      }
    None => ()
  }
  let objects = collect_json_objects(trimmed)
  let mut i = objects.length() - 1
  while i >= 0 {
    let slice = objects[i]
    match try_parse_json(slice) {
      Some(json) =>
        match json {
          Object(_) => return Some(json)
          _ => ()
        }
      None => ()
    }
    if i == 0 {
      break
    }
    i -= 1
  }
  None
}

fn trim_whitespace(text : String) -> String {
  text.trim(chars=" \n\t\r").to_string()
}

fn try_parse_json(text : String) -> Json? {
  try {
    let parsed = @json.parse(text)
    Some(parsed)
  } catch {
    _ => None
  }
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

fn last_index_of_char(text : String, ch : Char) -> Int {
  let mut idx = -1
  let mut i = 0
  for c in text {
    if c == ch {
      idx = i
    }
    i += 1
  }
  idx
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

fn collect_json_objects(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut depth = 0
  let mut start = -1
  let mut i = 0
  for c in text {
    if c == '{' {
      if depth == 0 {
        start = i
      }
      depth += 1
    } else if c == '}' {
      if depth > 0 {
        depth -= 1
        if depth == 0 && start >= 0 {
          out.push(substring(text, start, i + 1))
          start = -1
        }
      }
    }
    i += 1
  }
  out
}
