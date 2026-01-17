///|
struct Extractor {
  model : @model.Model
  window_size : Int
  overlap : Int
  token_counter : @token_counter.Counter
  safe_zone_tokens : Int
}

///|
pub fn Extractor::new(
  model~ : @model.Model,
  safe_zone_tokens~ : Int,
  window_size? : Int = 100,
  overlap? : Int = 20,
  logger~ : @pino.Logger,
) -> Extractor raise {
  Extractor::{
    model,
    token_counter: @token_counter.Counter::new(logger~),
    safe_zone_tokens,
    window_size,
    overlap,
  }
}

///|
fn split_content_with_sliding_window(
  content : String,
  window_size~ : Int,
  overlap~ : Int,
) -> Array[String] {
  let lines = content.split("\n").collect()
  let chunks = Array::new()
  for i in 0..<lines.length() {
    let start = i
    let end = i + window_size
    if end > lines.length() {
      break
    }
    let chunk = lines[start:end].join("\n")
    chunks.push(chunk)
    continue i + window_size - overlap
  }
  chunks
}

///|
const PartialNotice : String =
  #|<partial_content_process_note>
  #|The current processing is partial content from a file (lines marked in content),
  #|please judge relevance based only on the currently visible content and return the marked line ranges.
  #|</partial_content_process_note>

///|
const ExtractorRolePrompt : String =
  #|You are a code analysis assistant. Extract relevant code snippets based on the provided code file and conversation history.

///|
const ExtractorTaskPrompt : String =
  #|Task:
  #|1. Analyze the last user question and its context.
  #|2. Find one or more important code segments related to the question in the code file.
  #|3. For each relevant code segment, determine its start_line and end_line.
  #|4. Maximum 4 code segments.
  #|
  #|Output requirements:
  #|1. Return a JSON array, each element contains "start_line" and "end_line".
  #|2. start_line and end_line must be integers representing line numbers in the code file.
  #|3. Line numbers start from 1.
  #|4. If no relevant code segments, return empty array [].
  #|
  #|Output format:
  #|Strict JSON array without other text or explanations.
  #|
  #|```json
  #|[
  #|  {"start_line": first_segment_start_line, "end_line": first_segment_end_line},
  #|  {"start_line": second_segment_start_line, "end_line": second_segment_end_line}
  #|]
  #|```

///|
async fn Extractor::extract_code_snippets_from_chunk(
  self : Extractor,
  content : String,
  history~ : Array[@openai.ChatCompletionMessageParam],
  partial? : Bool = false,
) -> Json {
  let prompts = [ExtractorRolePrompt]
  if partial {
    prompts.push(PartialNotice)
  }
  prompts.push("Input:")
  prompts.push("1. Code file content:")
  prompts.push("<code_file>")
  prompts.push(content)
  prompts.push("</code_file>")
  prompts.push("2. Conversation history:")
  prompts.push("<conversation_history>")
  fn content(parts : Array[@openai.ChatCompletionContentPartParam]) -> String {
    let builder = StringBuilder::new()
    for part in parts {
      match part {
        Text(text) => builder.write_string(text.text)
      }
    }
    builder.to_string()
  }

  for message in history {
    match message {
      User(user) => prompts.push("User: \{content(user.content)}")
      Assistant(assistant) =>
        prompts.push("Assistant: \{content(assistant.content)}")
      System(system) => prompts.push("System: \{content(system.content)}")
      Tool(tool) => prompts.push("Tool: \{content(tool.content)}")
    }
  }
  prompts.push("</conversation_history>")
  prompts.push(ExtractorTaskPrompt)
  let prompt = prompts.join("\n")
  @openai.json(model=self.model, prompt~)
}

///|
struct Range {
  start_line : Int
  end_line : Int
}

///|
pub impl @json.FromJson for Range with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> Range raise {
  guard json is { "start_line": start_line, "end_line": end_line, .. } else {
    raise @json.JsonDecodeError(
      (json_path, "Expected object with start_line and end_line"),
    )
  }
  let start_line : Int = @json.from_json(
    start_line,
    path=json_path.add_key("start_line"),
  )
  let end_line : Int = @json.from_json(
    end_line,
    path=json_path.add_key("end_line"),
  )
  Range::{ start_line, end_line }
}

///|
fn merge_overlapping_snippets(snippets : Array[Range]) -> Array[Range] {
  if snippets.is_empty() {
    return snippets
  }
  snippets.sort_by((a, b) => a.start_line - b.start_line)
  let merged = Array::new()
  let mut current = snippets[0]
  for i in 1..<snippets.length() {
    let snippet = snippets[i]
    if snippet.start_line <= current.end_line {
      merged[merged.length() - 1] = Range::{
        start_line: current.start_line,
        end_line: @cmp.maximum(current.end_line, snippet.end_line),
      }
    } else {
      merged.push(current)
      current = snippet
    }
  }
  merged.push(current)
  merged
}

///|
fn build_snippet_content(content : String, snippets : Array[Range]) -> String {
  let lines = content.split("\n").collect()
  let builder = StringBuilder::new()
  builder.write_string("Snippets:\n")
  for snippet in snippets {
    let start = @cmp.maximum(0, snippet.start_line - 1)
    let end = @cmp.minimum(lines.length(), snippet.end_line)
    builder.write_string("# Lines \{start + 1}-\{end}\n")
    for i in start..<end {
      let line = lines[i]
      builder.write_substring(line.data(), 0, line.length())
      builder.write_char('\n')
    }
  }
  builder.to_string()
}

///|
pub async fn Extractor::extract_code_snippets(
  self : Extractor,
  content : String,
  history~ : Array[@openai.ChatCompletionMessageParam],
) -> String? {
  let token_count = self.token_counter.count_string(content)
  if token_count > self.safe_zone_tokens {
    let chunks = split_content_with_sliding_window(
      content,
      window_size=self.window_size,
      overlap=self.overlap,
    )
    let snippets : Array[Range] = []
    for i in 0..<chunks.length() {
      let chunk = chunks[i]
      let extracted = self.extract_code_snippets_from_chunk(
        chunk,
        history~,
        partial=true,
      )
      try {
        let snippet : Range = extracted |> @json.from_json()
        snippets.push(snippet)
      } catch {
        _ => continue
      }
    }
    let snippets = merge_overlapping_snippets(snippets)
    if snippets.is_empty() {
      None
    } else {
      Some(build_snippet_content(content, snippets))
    }
  } else {
    let content = content.split("\n").mapi((i, s) => "\{i + 1} \{s}").join("\n")
    let snippets = self.extract_code_snippets_from_chunk(
      content,
      history~,
      partial=false,
    )
    let snippets : Array[Range] = @json.from_json(snippets) catch {
      _ => return None
    }
    Some(build_snippet_content(content, snippets))
  }
}
