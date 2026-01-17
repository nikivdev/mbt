///|
async test "format_log_entry/PostToolCall" {
  let formatter = Formatter::new("test.md")
  let log_entry : Json = {
    "msg": "PostToolCall",
    "name": "get_weather",
    "text": "The weather in New York is sunny.",
  }
  formatter.format_log_entry(log_entry)
  inspect(
    formatter.to_string(),
    content=(
      #|# 1 Tool call result: <get_weather>
      #|
      #|````markdown
      #|The weather in New York is sunny.
      #|````
      #|
    ),
  )
}

///|
async test "format_log_entry/PostToolCall-with-result" {
  let formatter = Formatter::new("test.md")
  let log_entry : Json = {
    "msg": "PostToolCall",
    "name": "get_weather",
    "result": {
      "location": "New York",
      "temperature": "25°C",
      "condition": "Sunny",
    },
    "text": "The weather in New York is sunny.",
  }
  formatter.format_log_entry(log_entry)
  inspect(
    formatter.to_string(),
    content=(
      #|# 1 Tool call result: <get_weather>
      #|
      #|````markdown
      #|The weather in New York is sunny.
      #|````
      #|
    ),
  )
}

///|
async test "format_log_entry/PostToolCall-with-error" {
  let formatter = Formatter::new("test.md")
  let log_entry : Json = {
    "msg": "PostToolCall",
    "name": "get_weather",
    "error": { "message": "Location not found." },
    "text": "Error: Location not found.",
  }
  formatter.format_log_entry(log_entry)
  inspect(
    formatter.to_string(),
    content=(
      #|# 1 ❌ Tool call error: <get_weather>
      #|
      #|````markdown
      #|Error: Location not found.
      #|````
      #|
    ),
  )
}

///|
async test "format_log_entry/MessageAdded with multiline tool content" {
  let formatter = Formatter::new("test.md")
  let log_entry : Json = {
    "msg": "MessageAdded",
    "message": {
      "role": "tool",
      "tool_call_id": "call_123",
      "content": [
        {
          "type": "text",
          "text": "✅ Operation completed: Marked task as completed\n\n📝 Current todo list:\n  🟡 ✅ [ea45749e] Create project structure\n  🟡 ⏳ [1efbf50f] Define data structures\n\n📊 Summary: Total 2 items",
        },
      ],
    },
  }
  formatter.format_log_entry(log_entry)
  // The tool message should be ignored and produce no output, as the result
  // is already logged in PostToolCall.
  inspect(formatter.to_string(), content="")
  let log_entry : Json = {
    "msg": "MessageAdded",
    "message": {
      "role": "system",
      "content": [
        { "type": "text", "text": "System maintenance scheduled at midnight." },
      ],
    },
  }
  formatter.format_log_entry(log_entry)
  // The system message should be ignored and produce no output.
  inspect(
    formatter.to_string(),
    content=(
      #|# 1 System
      #|
      #|```markdown
      #|System maintenance scheduled at midnight.
      #|```
      #|
    ),
  )
}

///|
async test "format_log_entry/MessageAdded" {
  let formatter = Formatter::new("test.md")
  let log_entry : Json = {
    "msg": "MessageAdded",
    "message": {
      "role": "user",
      "content": [{ "type": "text", "text": "Hello, how are you?" }],
    },
  }
  formatter.format_log_entry(log_entry)
  inspect(
    formatter.to_string(),
    content=(
      #|# 1 User: Hello, how are you?
      #|
      #|Hello, how are you?
      #|
    ),
  )
}

///|
async test "format_log_entry/RequestCompleted" {
  let formatter = Formatter::new("test.md")
  let log_entry : Json = {
    "msg": "RequestCompleted",
    "message": {
      "role": "assistant",
      "content": "I am fine, thank you!",
      "tool_calls": [
        {
          "id": "tool_call_1",
          "function": {
            "name": "get_weather",
            "arguments": "{\"location\": \"New York\"}",
          },
        },
      ],
    },
  }
  formatter.format_log_entry(log_entry)
  inspect(
    formatter.to_string(),
    content=(
      #|# 1 Assistant: I am fine, thank you!
      #|
      #|I am fine, thank you!
      #|
      #|## Tool call argument: <get_weather>
      #|
      #|<location>
      #|  New York
      #|</location>
      #|
      #|### Original JSON payload
      #|
      #|```json
      #|{
      #|  "location": "New York"
      #|}
      #|```
      #|
    ),
  )
}

///|
test "recover_diagnostics" {
  let recovered = recover_diagnostics(
    (
      #|# 1 User: You are a MoonBit syntax fixing assistant. A file has been written but contains syntax errors that need to be fixed.
      #|
      #|You are a MoonBit syntax fixing assistant. A file has been written but contains syntax errors that need to be fixed.
      #|
      #|
      #|**Task Description:**
      #|Fixing syntax errors in the JSON parser implementation
      #|
      #|
      #|**File Path:** /var/folders/jb/64x3jtc51qbfk3y1m9f3yvyc0000gn/T/maria-test-VIaQeK5/json_parser/json.mbt
      #|
      #|
      #|**Current Syntax Errors:**
      #|error[3002]: json.mbt:32:10: Parse error, unexpected token `{`, you may expect `;` or `}`.
      #|error[3002]: json.mbt:37:2: Parse error, unexpected token `}`, you may expect `pub`, `priv`, `type`, `suberror`, `typealias`, `async`, `fn`, `fnalias`, `struct`, `enum`, `let`, `const`, `extern`, `test`, `impl`, `trait`, `traitalias`, `enumview`, `#attribute` or `using`.
      #|error[3002]: json.mbt:67:9: Using match expression in condition directly is not allowed. Consider using a let binding or wrapping it in parentheses.
      #|error[3002]: json.mbt:236:13: Using match expression in condition directly is not allowed. Consider using a let binding or wrapping it in parentheses.
      #|error[3002]: json.mbt:261:17: Using match expression in condition directly is not allowed. Consider using a let binding or wrapping it in parentheses.
      #|error[3002]: json.mbt:297:17: Using match expression in condition directly is not allowed. Consider using a let binding or wrapping it in parentheses.
      #|error[3002]: json.mbt:433:37: Parse error, unexpected token id (lowercase start), you may expect `{`.
      #|error[3002]: json.mbt:435:2: Parse error, unexpected token `}`, you may expect `pub`, `priv`, `type`, `suberror`, `typealias`, `async`, `fn`, `fnalias`, `struct`, `enum`, `let`, `const`, `extern`, `test`, `impl`, `trait`, `traitalias`, `enumview`, `#attribute` or `using`.
      #|
      #|
      #|**Your Task:**
      #|
      #|1. Use `read_file` to examine the current file contents
      #|
      #|2. Use `submit_fixed_file` to provide the complete fixed file content
      #|
      #|3. Only fix syntax errors - do not change logic unless absolutely necessary
      #|
      #|4. Continue until all syntax errors are fixed
      #|
      #|5. Call `attempt_completion` when done
      #|
      #|
      #|**Guidelines:**
      #|
      #|- Focus only on fixing syntax errors, not improving code quality
      #|
      #|- Preserve the original intent and functionality of the code, as much as possible
      #|
      #|- Use proper MoonBit syntax and conventions
      #|
      #|- If you cannot fix an error, explain why clearly
      #|
      #|- When syntax check passes, call `attempt_completion` immediately
      #|
      #|
      #|Please start by using `read_file` to examine the current file, then use `submit_fixed_file` to fix the syntax errors.
      #|
      #|# 2 Assistant
      #|
      #|## Tool call argument: <read_file>
      #|
      #|<path>
      #|  /var/folders/jb/64x3jtc51qbfk3y1m9f3yvyc0000gn/T/maria-test-VIaQeK5/json_parser/json.mbt
      #|</path>
      #|
      #|# 3 Tool call result: <read_file>
      #|
      #|````markdown
      #|File content:
      #|///|
      #|/// JSON data structure
      #|pub enum Json {
      #|  Null
      #|  Bool(Bool)
      #|  Number(Double)
      #|  String(String)
      #|  Array(Array[Json])
      #|  Object(Map[String, Json])
      #|} 
      #|derive(Show, Eq, ToJson)
      #|
      #|///|
      #|/// Parse error types
      #|pub(all) suberror ParseError {
      #|  UnexpectedChar(Int, Char)  // position, character
      #|  UnexpectedEof
      #|  InvalidNumber(Int, String)  // position, number string
      #|  InvalidEscapeSequence(Int, String)  // position, escape sequence
      #|  TrailingCharacters(Int)  // position
      #|} 
      #|derive(Eq, ToJson, Show)
      #|
      #|///|
      #|struct Parser {
      #|  text : String
      #|  pos : Ref[Int]
      #|}
      #|
      #|///|
      #|fn new_parser(text : String) -> Parser {
      #|  Parser {
      #|    text: text,
      #|    pos: Ref::new(0)
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::current_position(self : Parser) -> Int {
      #|  self.pos.val
      #|}
      #|
      #|///|
      #|fn Parser::peek_char(self : Parser) -> Char? {
      #|  let pos = self.pos.val
      #|  if pos < self.text.length() {
      #|    self.text.get_char(pos)
      #|  } else {
      #|    None
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::next_char(self : Parser) -> Char? {
      #|  let pos = self.pos.val
      #|  if pos < self.text.length() {
      #|    let ch = self.text.get_char(pos).unwrap()
      #|    self.pos.val = pos + 1
      #|    Some(ch)
      #|  } else {
      #|    None
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::skip_whitespace(self : Parser) -> Unit {
      #|  while match self.peek_char() {
      #|    Some(' ' | '\t' | '\n' | '\r') => {
      #|      ignore(self.next_char())
      #|      true
      #|    }
      #|    _ => false
      #|  } {}
      #|}
      #|
      #|///|
      #|fn Parser::parse_json(self : Parser) -> Json raise ParseError {
      #|  self.skip_whitespace()
      #|  let result = self.parse_value()
      #|  self.skip_whitespace()
      #|  
      #|  // Check for trailing characters
      #|  match self.peek_char() {
      #|    Some(_) => {
      #|      raise ParseError::TrailingCharacters(self.current_position())
      #|    }
      #|    None => result
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::parse_value(self : Parser) -> Json raise ParseError {
      #|  self.skip_whitespace()
      #|  match self.peek_char() {
      #|    Some('n') => self.parse_null()
      #|    Some('t') => self.parse_true()
      #|    Some('f') => self.parse_false()
      #|    Some('"') => self.parse_string()
      #|    Some('[') => self.parse_array()
      #|    Some('{') => self.parse_object()
      #|    Some(ch) if (ch is ('0'..='9')) || (ch == '-') => self.parse_number()
      #|    Some(ch) => {
      #|      raise ParseError::UnexpectedChar(self.current_position(), ch)
      #|    }
      #|    None => {
      #|      raise ParseError::UnexpectedEof
      #|    }
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::parse_null(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('n')
      #|  self.expect_char('u')
      #|  self.expect_char('l')
      #|  self.expect_char('l')
      #|  Json::Null
      #|}
      #|
      #|///|
      #|fn Parser::parse_true(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('t')
      #|  self.expect_char('r')
      #|  self.expect_char('u')
      #|  self.expect_char('e')
      #|  Json::Bool(true)
      #|}
      #|
      #|///|
      #|fn Parser::parse_false(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('f')
      #|  self.expect_char('a')
      #|  self.expect_char('l')
      #|  self.expect_char('s')
      #|  self.expect_char('e')
      #|  Json::Bool(false)
      #|}
      #|
      #|///|
      #|fn Parser::expect_char(self : Parser, expected : Char) -> Unit raise ParseError {
      #|  match self.next_char() {
      #|    Some(ch) if ch == expected => ()
      #|    Some(ch) => {
      #|      raise ParseError::UnexpectedChar(self.current_position(), ch)
      #|    }
      #|    None => {
      #|      raise ParseError::UnexpectedEof
      #|    }
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::parse_string(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('"')
      #|  let mut result = ""
      #|  
      #|  while true {
      #|    match self.next_char() {
      #|      Some('"') => break
      #|      Some('\\') => {
      #|        let escaped = self.parse_escape_sequence()
      #|        result = result + escaped
      #|      }
      #|      Some(ch) => {
      #|        result = result + @string.from_char(ch)
      #|      }
      #|      None => {
      #|        raise ParseError::UnexpectedEof
      #|      }
      #|    }
      #|  }
      #|  
      #|  Json::String(result)
      #|}
      #|
      #|///|
      #|fn Parser::parse_escape_sequence(self : Parser) -> String raise ParseError {
      #|  match self.next_char() {
      #|    Some('"') => "\""
      #|    Some('\\') => "\\"
      #|    Some('/') => "/"
      #|    Some('b') => "\b" // Backspace
      #|    Some('f') => "\f" // Form feed
      #|    Some('n') => "\n"
      #|    Some('r') => "\r"
      #|    Some('t') => "\t"
      #|    Some('u') => {
      #|      // Unicode escape sequence
      #|      let mut code = 0
      #|      for i = 0; i < 4; i = i + 1 {
      #|        match self.next_char() {
      #|          Some(ch) if ch is ('0'..='9') => {
      #|            code = code * 16 + (ch - '0')
      #|          }
      #|          Some(ch) if ch is ('a'..='f') => {
      #|            code = code * 16 + (ch - 'a' + 10)
      #|          }
      #|          Some(ch) if ch is ('A'..='F') => {
      #|            code = code * 16 + (ch - 'A' + 10)
      #|          }
      #|          Some(ch) => {
      #|            raise ParseError::InvalidEscapeSequence(self.current_position(), "\\u" + @string.from_char(ch))
      #|          }
      #|          None => {
      #|            raise ParseError::UnexpectedEof
      #|          }
      #|        }
      #|      }
      #|      @string.from_char(code)
      #|    }
      #|    Some(ch) => {
      #|      raise ParseError::InvalidEscapeSequence(self.current_position(), "\\" + @string.from_char(ch))
      #|    }
      #|    None => {
      #|      raise ParseError::UnexpectedEof
      #|    }
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::parse_number(self : Parser) -> Json raise ParseError {
      #|  let start_pos = self.pos.val
      #|  
      #|  // Parse optional minus sign
      #|  match self.peek_char() {
      #|    Some('-') => {
      #|      ignore(self.next_char())
      #|    }
      #|    _ => ()
      #|  }
      #|  
      #|  // Parse integer part
      #|  match self.peek_char() {
      #|    Some(ch) if ch is ('0'..='9') => {
      #|      ignore(self.next_char())
      #|      while match self.peek_char() {
      #|        Some(ch) if ch is ('0'..='9') => {
      #|          ignore(self.next_char())
      #|          true
      #|        }
      #|        _ => false
      #|      } {}
      #|    }
      #|    _ => {
      #|      // No digits found
      #|      let end_pos = self.pos.val
      #|      let number_str = self.text.slice(start_pos, end_pos)
      #|      raise ParseError::InvalidNumber(self.current_position(), number_str)
      #|    }
      #|  }
      #|  
      #|  // Parse optional decimal part
      #|  match self.peek_char() {
      #|    Some('.') => {
      #|      ignore(self.next_char()) // consume '.'
      #|      
      #|      // Parse fractional part
      #|      match self.peek_char() {
      #|        Some(ch) if ch is ('0'..='9') => {
      #|          ignore(self.next_char())
      #|          while match self.peek_char() {
      #|            Some(ch) if ch is ('0'..='9') => {
      #|              ignore(self.next_char())
      #|              true
      #|            }
      #|            _ => false
      #|          } {}
      #|        }
      #|        _ => {
      #|          // Decimal point with no digits after
      #|          let end_pos = self.pos.val
      #|          let number_str = self.text.slice(start_pos, end_pos)
      #|          raise ParseError::InvalidNumber(self.current_position(), number_str)
      #|        }
      #|      }
      #|    }
      #|    _ => ()
      #|  }
      #|  
      #|  // Parse optional exponent part
      #|  match self.peek_char() {
      #|    Some('e' | 'E') => {
      #|      ignore(self.next_char()) // consume 'e' or 'E'
      #|      
      #|      // Parse optional sign
      #|      match self.peek_char() {
      #|        Some('+' | '-') => {
      #|          ignore(self.next_char())
      #|        }
      #|        _ => ()
      #|      }
      #|      
      #|      // Parse exponent digits
      #|      match self.peek_char() {
      #|        Some(ch) if ch is ('0'..='9') => {
      #|          ignore(self.next_char())
      #|          while match self.peek_char() {
      #|            Some(ch) if ch is ('0'..='9') => {
      #|              ignore(self.next_char())
      #|              true
      #|            }
      #|            _ => false
      #|          } {}
      #|        }
      #|        _ => {
      #|          // 'e' or 'E' with no digits after
      #|          let end_pos = self.pos.val
      #|          let number_str = self.text.slice(start_pos, end_pos)
      #|          raise ParseError::InvalidNumber(self.current_position(), number_str)
      #|        }
      #|      }
      #|    }
      #|    _ => ()
      #|  }
      #|  
      #|  let end_pos = self.pos.val
      #|  let number_str = self.text.slice(start_pos, end_pos)
      #|  
      #|  match @double.parse(number_str) {
      #|    Ok(value) => Json::Number(value)
      #|    Err(_) => {
      #|      raise ParseError::InvalidNumber(self.current_position(), number_str)
      #|    }
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::parse_array(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('[')
      #|  self.skip_whitespace()
      #|  
      #|  let mut array : Array[Json] = []
      #|  
      #|  // Check for empty array
      #|  match self.peek_char() {
      #|    Some(']') => {
      #|      ignore(self.next_char())
      #|      return Json::Array(array)
      #|    }
      #|    _ => ()
      #|  }
      #|  
      #|  // Parse array elements
      #|  while true {
      #|    self.skip_whitespace()
      #|    let value = self.parse_value()
      #|    array.push(value)
      #|    
      #|    self.skip_whitespace()
      #|    match self.next_char() {
      #|      Some(',') => {
      #|        // Continue to next element
      #|      }
      #|      Some(']') => {
      #|        break
      #|      }
      #|      Some(ch) => {
      #|        raise ParseError::UnexpectedChar(self.current_position(), ch)
      #|      }
      #|      None => {
      #|        raise ParseError::UnexpectedEof
      #|      }
      #|    }
      #|  }
      #|  
      #|  Json::Array(array)
      #|}
      #|
      #|///|
      #|fn Parser::parse_object(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('{')
      #|  self.skip_whitespace()
      #|  
      #|  let mut object : Map[String, Json] = Map::new()
      #|  
      #|  // Check for empty object
      #|  match self.peek_char() {
      #|    Some('}') => {
      #|      ignore(self.next_char())
      #|      return Json::Object(object)
      #|    }
      #|    _ => ()
      #|  }
      #|  
      #|  // Parse key-value pairs
      #|  while true {
      #|    self.skip_whitespace()
      #|    
      #|    // Parse key
      #|    let key_json = self.parse_string()
      #|    let key = match key_json {
      #|      Json::String(s) => s
      #|      _ => {
      #|        // This shouldn't happen as parse_string always returns Json::String
      #|        raise ParseError::UnexpectedChar(self.current_position(), '"')
      #|      }
      #|    }
      #|    
      #|    // Parse colon
      #|    self.skip_whitespace()
      #|    self.expect_char(':')
      #|    
      #|    // Parse value
      #|    self.skip_whitespace()
      #|    let value = self.parse_value()
      #|    object.set(key, value)
      #|    
      #|    // Check for comma or closing brace
      #|    self.skip_whitespace()
      #|    match self.next_char() {
      #|      Some(',') => {
      #|        // Continue to next key-value pair
      #|      }
      #|      Some('}') => {
      #|        break
      #|      }
      #|      Some(ch) => {
      #|        raise ParseError::UnexpectedChar(self.current_position(), ch)
      #|      }
      #|      None => {
      #|        raise ParseError::UnexpectedEof
      #|      }
      #|    }
      #|  }
      #|  
      #|  Json::Object(object)
      #|}
      #|
      #|///|
      #|/// Public API function to parse a JSON string
      #|pub fn parse(json_str : String) -> Result[Json, ParseError] {
      #|  let parser = new_parser(json_str)
      #|  try { parser.parse_json() } catch e { Err(e) }
      #|}
      #|
      #|///|
      #|/// Convert Json value to string representation
      #|pub fn Json::to_json_string(self : Json) -> String {
      #|  match self {
      #|    Null => "null"
      #|    Bool(b) => if b { "true" } else { "false" }
      #|    Number(n) => @double.to_string(n)
      #|    String(s) => {
      #|      // TODO: Properly escape string values
      #|      "\"\{s}\""
      #|    }
      #|    Array(arr) => {
      #|      let mut result = "["
      #|      for i = 0; i < arr.length(); i = i + 1 {
      #|        if i > 0 {
      #|          result = result + ","
      #|        }
      #|        result = result + arr[i].to_json_string()
      #|      }
      #|      result + "]"
      #|    }
      #|    Object(obj) => {
      #|      let mut result = "{"
      #|      let keys = obj.keys().to_array()
      #|      for i = 0; i < keys.length(); i = i + 1 {
      #|        if i > 0 {
      #|          result = result + ","
      #|        }
      #|        let key = keys[i]
      #|        let value = obj.get(key).unwrap()
      #|        // TODO: Properly escape key values
      #|        result = result + "\"\{key}\":" + value.to_json_string()
      #|      }
      #|      result + "}"
      #|    }
      #|  }
      #|}
      #|````
      #|
    ),
  )
  inspect(
    recovered,
    content=(
      #|# 1 User: You are a MoonBit syntax fixing assistant. A file has been written but contains syntax errors that need to be fixed.
      #|
      #|You are a MoonBit syntax fixing assistant. A file has been written but contains syntax errors that need to be fixed.
      #|
      #|
      #|**Task Description:**
      #|Fixing syntax errors in the JSON parser implementation
      #|
      #|
      #|**File Path:** /var/folders/jb/64x3jtc51qbfk3y1m9f3yvyc0000gn/T/maria-test-VIaQeK5/json_parser/json.mbt
      #|
      #|
      #|**Current Syntax Errors:**
      #|error[3002]: json.mbt:32:10: Parse error, unexpected token `{`, you may expect `;` or `}`.
      #|   │fn new_parser(text : String) -> Parser {
      #|32 │  Parser {
      #|   │         ^
      #|   │    text: text,
      #|error[3002]: json.mbt:37:2: Parse error, unexpected token `}`, you may expect `pub`, `priv`, `type`, `suberror`, `typealias`, `async`, `fn`, `fnalias`, `struct`, `enum`, `let`, `const`, `extern`, `test`, `impl`, `trait`, `traitalias`, `enumview`, `#attribute` or `using`.
      #|   │}
      #|37 │
      #|   │ ^
      #|   │///|
      #|error[3002]: json.mbt:67:9: Using match expression in condition directly is not allowed. Consider using a let binding or wrapping it in parentheses.
      #|   │fn Parser::skip_whitespace(self : Parser) -> Unit {
      #|67 │  while match self.peek_char() {
      #|   │        ^
      #|   │    Some(' ' | '\t' | '\n' | '\r') => {
      #|error[3002]: json.mbt:236:13: Using match expression in condition directly is not allowed. Consider using a let binding or wrapping it in parentheses.
      #|    │      ignore(self.next_char())
      #|236 │      while match self.peek_char() {
      #|    │            ^
      #|    │        Some(ch) if ch is ('0'..='9') => {
      #|error[3002]: json.mbt:261:17: Using match expression in condition directly is not allowed. Consider using a let binding or wrapping it in parentheses.
      #|    │          ignore(self.next_char())
      #|261 │          while match self.peek_char() {
      #|    │                ^
      #|    │            Some(ch) if ch is ('0'..='9') => {
      #|error[3002]: json.mbt:297:17: Using match expression in condition directly is not allowed. Consider using a let binding or wrapping it in parentheses.
      #|    │          ignore(self.next_char())
      #|297 │          while match self.peek_char() {
      #|    │                ^
      #|    │            Some(ch) if ch is ('0'..='9') => {
      #|error[3002]: json.mbt:433:37: Parse error, unexpected token id (lowercase start), you may expect `{`.
      #|    │  let parser = new_parser(json_str)
      #|433 │  try { parser.parse_json() } catch e { Err(e) }
      #|    │                                    ^
      #|    │}
      #|error[3002]: json.mbt:435:2: Parse error, unexpected token `}`, you may expect `pub`, `priv`, `type`, `suberror`, `typealias`, `async`, `fn`, `fnalias`, `struct`, `enum`, `let`, `const`, `extern`, `test`, `impl`, `trait`, `traitalias`, `enumview`, `#attribute` or `using`.
      #|    │}
      #|435 │
      #|    │ ^
      #|    │///|
      #|
      #|
      #|**Your Task:**
      #|
      #|1. Use `read_file` to examine the current file contents
      #|
      #|2. Use `submit_fixed_file` to provide the complete fixed file content
      #|
      #|3. Only fix syntax errors - do not change logic unless absolutely necessary
      #|
      #|4. Continue until all syntax errors are fixed
      #|
      #|5. Call `attempt_completion` when done
      #|
      #|
      #|**Guidelines:**
      #|
      #|- Focus only on fixing syntax errors, not improving code quality
      #|
      #|- Preserve the original intent and functionality of the code, as much as possible
      #|
      #|- Use proper MoonBit syntax and conventions
      #|
      #|- If you cannot fix an error, explain why clearly
      #|
      #|- When syntax check passes, call `attempt_completion` immediately
      #|
      #|
      #|Please start by using `read_file` to examine the current file, then use `submit_fixed_file` to fix the syntax errors.
      #|
      #|# 2 Assistant
      #|
      #|## Tool call argument: <read_file>
      #|
      #|<path>
      #|  /var/folders/jb/64x3jtc51qbfk3y1m9f3yvyc0000gn/T/maria-test-VIaQeK5/json_parser/json.mbt
      #|</path>
      #|
      #|# 3 Tool call result: <read_file>
      #|
      #|````markdown
      #|File content:
      #|///|
      #|/// JSON data structure
      #|pub enum Json {
      #|  Null
      #|  Bool(Bool)
      #|  Number(Double)
      #|  String(String)
      #|  Array(Array[Json])
      #|  Object(Map[String, Json])
      #|} 
      #|derive(Show, Eq, ToJson)
      #|
      #|///|
      #|/// Parse error types
      #|pub(all) suberror ParseError {
      #|  UnexpectedChar(Int, Char)  // position, character
      #|  UnexpectedEof
      #|  InvalidNumber(Int, String)  // position, number string
      #|  InvalidEscapeSequence(Int, String)  // position, escape sequence
      #|  TrailingCharacters(Int)  // position
      #|} 
      #|derive(Eq, ToJson, Show)
      #|
      #|///|
      #|struct Parser {
      #|  text : String
      #|  pos : Ref[Int]
      #|}
      #|
      #|///|
      #|fn new_parser(text : String) -> Parser {
      #|  Parser {
      #|    text: text,
      #|    pos: Ref::new(0)
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::current_position(self : Parser) -> Int {
      #|  self.pos.val
      #|}
      #|
      #|///|
      #|fn Parser::peek_char(self : Parser) -> Char? {
      #|  let pos = self.pos.val
      #|  if pos < self.text.length() {
      #|    self.text.get_char(pos)
      #|  } else {
      #|    None
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::next_char(self : Parser) -> Char? {
      #|  let pos = self.pos.val
      #|  if pos < self.text.length() {
      #|    let ch = self.text.get_char(pos).unwrap()
      #|    self.pos.val = pos + 1
      #|    Some(ch)
      #|  } else {
      #|    None
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::skip_whitespace(self : Parser) -> Unit {
      #|  while match self.peek_char() {
      #|    Some(' ' | '\t' | '\n' | '\r') => {
      #|      ignore(self.next_char())
      #|      true
      #|    }
      #|    _ => false
      #|  } {}
      #|}
      #|
      #|///|
      #|fn Parser::parse_json(self : Parser) -> Json raise ParseError {
      #|  self.skip_whitespace()
      #|  let result = self.parse_value()
      #|  self.skip_whitespace()
      #|  
      #|  // Check for trailing characters
      #|  match self.peek_char() {
      #|    Some(_) => {
      #|      raise ParseError::TrailingCharacters(self.current_position())
      #|    }
      #|    None => result
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::parse_value(self : Parser) -> Json raise ParseError {
      #|  self.skip_whitespace()
      #|  match self.peek_char() {
      #|    Some('n') => self.parse_null()
      #|    Some('t') => self.parse_true()
      #|    Some('f') => self.parse_false()
      #|    Some('"') => self.parse_string()
      #|    Some('[') => self.parse_array()
      #|    Some('{') => self.parse_object()
      #|    Some(ch) if (ch is ('0'..='9')) || (ch == '-') => self.parse_number()
      #|    Some(ch) => {
      #|      raise ParseError::UnexpectedChar(self.current_position(), ch)
      #|    }
      #|    None => {
      #|      raise ParseError::UnexpectedEof
      #|    }
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::parse_null(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('n')
      #|  self.expect_char('u')
      #|  self.expect_char('l')
      #|  self.expect_char('l')
      #|  Json::Null
      #|}
      #|
      #|///|
      #|fn Parser::parse_true(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('t')
      #|  self.expect_char('r')
      #|  self.expect_char('u')
      #|  self.expect_char('e')
      #|  Json::Bool(true)
      #|}
      #|
      #|///|
      #|fn Parser::parse_false(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('f')
      #|  self.expect_char('a')
      #|  self.expect_char('l')
      #|  self.expect_char('s')
      #|  self.expect_char('e')
      #|  Json::Bool(false)
      #|}
      #|
      #|///|
      #|fn Parser::expect_char(self : Parser, expected : Char) -> Unit raise ParseError {
      #|  match self.next_char() {
      #|    Some(ch) if ch == expected => ()
      #|    Some(ch) => {
      #|      raise ParseError::UnexpectedChar(self.current_position(), ch)
      #|    }
      #|    None => {
      #|      raise ParseError::UnexpectedEof
      #|    }
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::parse_string(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('"')
      #|  let mut result = ""
      #|  
      #|  while true {
      #|    match self.next_char() {
      #|      Some('"') => break
      #|      Some('\\') => {
      #|        let escaped = self.parse_escape_sequence()
      #|        result = result + escaped
      #|      }
      #|      Some(ch) => {
      #|        result = result + @string.from_char(ch)
      #|      }
      #|      None => {
      #|        raise ParseError::UnexpectedEof
      #|      }
      #|    }
      #|  }
      #|  
      #|  Json::String(result)
      #|}
      #|
      #|///|
      #|fn Parser::parse_escape_sequence(self : Parser) -> String raise ParseError {
      #|  match self.next_char() {
      #|    Some('"') => "\""
      #|    Some('\\') => "\\"
      #|    Some('/') => "/"
      #|    Some('b') => "\b" // Backspace
      #|    Some('f') => "\f" // Form feed
      #|    Some('n') => "\n"
      #|    Some('r') => "\r"
      #|    Some('t') => "\t"
      #|    Some('u') => {
      #|      // Unicode escape sequence
      #|      let mut code = 0
      #|      for i = 0; i < 4; i = i + 1 {
      #|        match self.next_char() {
      #|          Some(ch) if ch is ('0'..='9') => {
      #|            code = code * 16 + (ch - '0')
      #|          }
      #|          Some(ch) if ch is ('a'..='f') => {
      #|            code = code * 16 + (ch - 'a' + 10)
      #|          }
      #|          Some(ch) if ch is ('A'..='F') => {
      #|            code = code * 16 + (ch - 'A' + 10)
      #|          }
      #|          Some(ch) => {
      #|            raise ParseError::InvalidEscapeSequence(self.current_position(), "\\u" + @string.from_char(ch))
      #|          }
      #|          None => {
      #|            raise ParseError::UnexpectedEof
      #|          }
      #|        }
      #|      }
      #|      @string.from_char(code)
      #|    }
      #|    Some(ch) => {
      #|      raise ParseError::InvalidEscapeSequence(self.current_position(), "\\" + @string.from_char(ch))
      #|    }
      #|    None => {
      #|      raise ParseError::UnexpectedEof
      #|    }
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::parse_number(self : Parser) -> Json raise ParseError {
      #|  let start_pos = self.pos.val
      #|  
      #|  // Parse optional minus sign
      #|  match self.peek_char() {
      #|    Some('-') => {
      #|      ignore(self.next_char())
      #|    }
      #|    _ => ()
      #|  }
      #|  
      #|  // Parse integer part
      #|  match self.peek_char() {
      #|    Some(ch) if ch is ('0'..='9') => {
      #|      ignore(self.next_char())
      #|      while match self.peek_char() {
      #|        Some(ch) if ch is ('0'..='9') => {
      #|          ignore(self.next_char())
      #|          true
      #|        }
      #|        _ => false
      #|      } {}
      #|    }
      #|    _ => {
      #|      // No digits found
      #|      let end_pos = self.pos.val
      #|      let number_str = self.text.slice(start_pos, end_pos)
      #|      raise ParseError::InvalidNumber(self.current_position(), number_str)
      #|    }
      #|  }
      #|  
      #|  // Parse optional decimal part
      #|  match self.peek_char() {
      #|    Some('.') => {
      #|      ignore(self.next_char()) // consume '.'
      #|      
      #|      // Parse fractional part
      #|      match self.peek_char() {
      #|        Some(ch) if ch is ('0'..='9') => {
      #|          ignore(self.next_char())
      #|          while match self.peek_char() {
      #|            Some(ch) if ch is ('0'..='9') => {
      #|              ignore(self.next_char())
      #|              true
      #|            }
      #|            _ => false
      #|          } {}
      #|        }
      #|        _ => {
      #|          // Decimal point with no digits after
      #|          let end_pos = self.pos.val
      #|          let number_str = self.text.slice(start_pos, end_pos)
      #|          raise ParseError::InvalidNumber(self.current_position(), number_str)
      #|        }
      #|      }
      #|    }
      #|    _ => ()
      #|  }
      #|  
      #|  // Parse optional exponent part
      #|  match self.peek_char() {
      #|    Some('e' | 'E') => {
      #|      ignore(self.next_char()) // consume 'e' or 'E'
      #|      
      #|      // Parse optional sign
      #|      match self.peek_char() {
      #|        Some('+' | '-') => {
      #|          ignore(self.next_char())
      #|        }
      #|        _ => ()
      #|      }
      #|      
      #|      // Parse exponent digits
      #|      match self.peek_char() {
      #|        Some(ch) if ch is ('0'..='9') => {
      #|          ignore(self.next_char())
      #|          while match self.peek_char() {
      #|            Some(ch) if ch is ('0'..='9') => {
      #|              ignore(self.next_char())
      #|              true
      #|            }
      #|            _ => false
      #|          } {}
      #|        }
      #|        _ => {
      #|          // 'e' or 'E' with no digits after
      #|          let end_pos = self.pos.val
      #|          let number_str = self.text.slice(start_pos, end_pos)
      #|          raise ParseError::InvalidNumber(self.current_position(), number_str)
      #|        }
      #|      }
      #|    }
      #|    _ => ()
      #|  }
      #|  
      #|  let end_pos = self.pos.val
      #|  let number_str = self.text.slice(start_pos, end_pos)
      #|  
      #|  match @double.parse(number_str) {
      #|    Ok(value) => Json::Number(value)
      #|    Err(_) => {
      #|      raise ParseError::InvalidNumber(self.current_position(), number_str)
      #|    }
      #|  }
      #|}
      #|
      #|///|
      #|fn Parser::parse_array(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('[')
      #|  self.skip_whitespace()
      #|  
      #|  let mut array : Array[Json] = []
      #|  
      #|  // Check for empty array
      #|  match self.peek_char() {
      #|    Some(']') => {
      #|      ignore(self.next_char())
      #|      return Json::Array(array)
      #|    }
      #|    _ => ()
      #|  }
      #|  
      #|  // Parse array elements
      #|  while true {
      #|    self.skip_whitespace()
      #|    let value = self.parse_value()
      #|    array.push(value)
      #|    
      #|    self.skip_whitespace()
      #|    match self.next_char() {
      #|      Some(',') => {
      #|        // Continue to next element
      #|      }
      #|      Some(']') => {
      #|        break
      #|      }
      #|      Some(ch) => {
      #|        raise ParseError::UnexpectedChar(self.current_position(), ch)
      #|      }
      #|      None => {
      #|        raise ParseError::UnexpectedEof
      #|      }
      #|    }
      #|  }
      #|  
      #|  Json::Array(array)
      #|}
      #|
      #|///|
      #|fn Parser::parse_object(self : Parser) -> Json raise ParseError {
      #|  self.expect_char('{')
      #|  self.skip_whitespace()
      #|  
      #|  let mut object : Map[String, Json] = Map::new()
      #|  
      #|  // Check for empty object
      #|  match self.peek_char() {
      #|    Some('}') => {
      #|      ignore(self.next_char())
      #|      return Json::Object(object)
      #|    }
      #|    _ => ()
      #|  }
      #|  
      #|  // Parse key-value pairs
      #|  while true {
      #|    self.skip_whitespace()
      #|    
      #|    // Parse key
      #|    let key_json = self.parse_string()
      #|    let key = match key_json {
      #|      Json::String(s) => s
      #|      _ => {
      #|        // This shouldn't happen as parse_string always returns Json::String
      #|        raise ParseError::UnexpectedChar(self.current_position(), '"')
      #|      }
      #|    }
      #|    
      #|    // Parse colon
      #|    self.skip_whitespace()
      #|    self.expect_char(':')
      #|    
      #|    // Parse value
      #|    self.skip_whitespace()
      #|    let value = self.parse_value()
      #|    object.set(key, value)
      #|    
      #|    // Check for comma or closing brace
      #|    self.skip_whitespace()
      #|    match self.next_char() {
      #|      Some(',') => {
      #|        // Continue to next key-value pair
      #|      }
      #|      Some('}') => {
      #|        break
      #|      }
      #|      Some(ch) => {
      #|        raise ParseError::UnexpectedChar(self.current_position(), ch)
      #|      }
      #|      None => {
      #|        raise ParseError::UnexpectedEof
      #|      }
      #|    }
      #|  }
      #|  
      #|  Json::Object(object)
      #|}
      #|
      #|///|
      #|/// Public API function to parse a JSON string
      #|pub fn parse(json_str : String) -> Result[Json, ParseError] {
      #|  let parser = new_parser(json_str)
      #|  try { parser.parse_json() } catch e { Err(e) }
      #|}
      #|
      #|///|
      #|/// Convert Json value to string representation
      #|pub fn Json::to_json_string(self : Json) -> String {
      #|  match self {
      #|    Null => "null"
      #|    Bool(b) => if b { "true" } else { "false" }
      #|    Number(n) => @double.to_string(n)
      #|    String(s) => {
      #|      // TODO: Properly escape string values
      #|      "\"\{s}\""
      #|    }
      #|    Array(arr) => {
      #|      let mut result = "["
      #|      for i = 0; i < arr.length(); i = i + 1 {
      #|        if i > 0 {
      #|          result = result + ","
      #|        }
      #|        result = result + arr[i].to_json_string()
      #|      }
      #|      result + "]"
      #|    }
      #|    Object(obj) => {
      #|      let mut result = "{"
      #|      let keys = obj.keys().to_array()
      #|      for i = 0; i < keys.length(); i = i + 1 {
      #|        if i > 0 {
      #|          result = result + ","
      #|        }
      #|        let key = keys[i]
      #|        let value = obj.get(key).unwrap()
      #|        // TODO: Properly escape key values
      #|        result = result + "\"\{key}\":" + value.to_json_string()
      #|      }
      #|      result + "}"
      #|    }
      #|  }
      #|}
      #|````
      #|
    ),
  )
}

///|
async test "ModelLoaded" {
  let log_entry : Json = {
    "level": 30,
    "pid": 49303,
    "msg": "ModelLoaded",
    "hostname": "Haoxiangs-MacBook-Pro.local",
    "time": 1761731846381,
    "tag": "maria_test",
    "name": ["qwen/qwen3-coder-plus"],
    "model": [
      {
        "name": "qwen/qwen3-coder-plus",
        "description": "Qwen coder",
        "model_name": "qwen/qwen3-coder-plus",
        "model_type": "saas/openai",
        "api_key": "sk-test",
        "base_url": "https://openrouter.ai/api/v1",
        "safe_zone_tokens": 256000,
        "supports_anthropic_prompt_caching": false,
      },
    ],
  }
  let formatter = Formatter::new("test.md")
  formatter.format_log_entry(log_entry)
  inspect(
    formatter.to_string(),
    content=(
      #|# System information
      #|
      #|00:00:00
      #|
      #|Model: qwen/qwen3-coder-plus
      #|
    ),
  )
}

///|
async test "subagent" (t : @test.Test) {
  @mock.run(t, mock => {
    let log_entries : Array[Json] = [
      {
        "msg": "MessageAdded",
        "tool": {
          "name": "meta_write_to_file",
          "id": "d9a50da2-c4d2-4177-8af4-f6a38d284e49",
        },
        "message": {
          "role": "user",
          "content": "You are a MoonBit syntax fixing assistant. A file has been written but contains syntax errors that need to be fixed.\n\n\n**Task Description:**\n\nCreate JSON lexer implementation\n\n**File Content:**\n\n```moonbit\n///|\n/// JSON lexer for tokenizing input strings\nstruct Lexer {\n  input : String\n  position : Int\n  read_position : Int\n  ch : Char?\n}\n\n///|\nfn new_lexer(input : String) -> Lexer {\n  let lexer = { input, position: 0, read_position: 0, ch: None }\n  read_char(lexer)\n  lexer\n}\n```\n\n**Current Syntax Errors:**\n\nerror[3002]: lexer.mbt: Parse error, unexpected token `}`, you may expect `{`.\n 45 │ }\n    │ ^\n\nerror[3002]: lexer.mbt: Parse error, unexpected token .., you may expect `,`, `:` or `)`.\n 87 │       Some(ch) if ch is ('0'..'9' | '.' | '-' | '+' | 'e' | 'E') => {\n    │                             ^^\n\nerror[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.\n 94 │   }\n    │    \n\nerror[3002]: lexer.mbt: Parse error, unexpected token `}`, you may expect `{`.\n 130 │ }\n     │ ^\n\nerror[3002]: lexer.mbt: Parse error, unexpected token .., you may expect `,`, `:` or `)`.\n 137 │       Some(ch) if ch is ('a'..'z' | 'A'..'Z' | '_') => {\n     │                             ^^\n\nerror[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.\n 144 │   }\n     │    \n\nerror[3002]: lexer.mbt: Parse error, unexpected token `?`, you may expect `;` or `}`.\n 189 │           read_string(lexer)?\n     │                             ^\n\nerror[3002]: lexer.mbt: Parse error, unexpected token .., you may expect `=>`.\n 191 │         '0'..'9' | '-' => {\n     │            ^^\n\nerror[3002]: lexer.mbt: Parse error, unexpected token character, you may expect id (lowercase start).\n 194 │         'a'..'z' | 'A'..'Z' | '_' => {\n     │              ^^^\n\nerror[3002]: lexer.mbt: Parse error, unexpected token id (uppercase start), you may expect `pub`, `priv`, `type`, `suberror`, `typealias`, `async`, `fn`, `fnalias`, `struct`, `enum`, `let`, `const`, `extern`, `test`, `impl`, `trait`, `traitalias`, `enumview`, `#attribute` or `using`.\n 203 │     None => {\n     │     ^^^^\n\n**Your Task:**\n\n1. Analyze the syntax errors and understand what needs to be fixed\n2. Use `submit_fixed_file` to provide the complete fixed file content\n3. Only fix syntax errors - do not change logic unless absolutely necessary\n4. Continue until all syntax errors are fixed\n5. Call `attempt_completion` when done\n\n**Guidelines:**\n\n- Focus only on fixing syntax errors, not improving code quality\n- Preserve the original intent and functionality of the code, as much as possible\n- Use proper MoonBit syntax and conventions\n- If you cannot fix an error, explain why clearly\n- When syntax check passes, call `attempt_completion` immediately",
        },
      },
      {
        "msg": "PreConversation",
        "tool": {
          "name": "meta_write_to_file",
          "id": "d9a50da2-c4d2-4177-8af4-f6a38d284e49",
        },
      },
      {
        "msg": "MessageAdded",
        "tool": {
          "name": "meta_write_to_file",
          "id": "d9a50da2-c4d2-4177-8af4-f6a38d284e49",
        },
        "message": {
          "role": "tool",
          "content": [{ "type": "text", "text": "Unknown tool: read_file" }],
          "tool_call_id": "call_802ee514f832463d96132b67",
        },
      },
      {
        "msg": "PostToolCall",
        "tool": {
          "name": "meta_write_to_file",
          "id": "d9a50da2-c4d2-4177-8af4-f6a38d284e49",
        },
        "name": "submit_fixed_file",
        "error": [
          "ToolFailure", "File verification failed with syntax errors:\nerror[3002]: lexer.mbt: Parse error, unexpected token `}`, you may expect `{`.\n 45 │ }\n    │ ^\n\nerror[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.\n 103 │   }\n     │    \n\nerror[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.\n 139 │   }\n     │    \n\nerror[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.\n 159 │   }\n     │    ",
        ],
        "text": "File verification failed with syntax errors:\nerror[3002]: lexer.mbt: Parse error, unexpected token `}`, you may expect `{`.\n 45 │ }\n    │ ^\n\nerror[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.\n 103 │   }\n     │    \n\nerror[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.\n 139 │   }\n     │    \n\nerror[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.\n 159 │   }\n     │    ",
      },
      {
        "msg": "MessageAdded",
        "tool": {
          "name": "meta_write_to_file",
          "id": "d9a50da2-c4d2-4177-8af4-f6a38d284e49",
        },
        "message": {
          "role": "tool",
          "content": [
            {
              "type": "text",
              "text": "File verification failed with syntax errors:\nerror[3002]: lexer.mbt: Parse error, unexpected token `}`, you may expect `{`.\n 45 │ }\n    │ ^\n\nerror[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.\n 103 │   }\n     │    \n\nerror[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.\n 139 │   }\n     │    \n\nerror[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.\n 159 │   }\n     │    ",
            },
          ],
          "tool_call_id": "call_55cce74b1c784a6cb81034e8",
        },
      },
    ]
    let formatter = Formatter::new(@path.join(mock.cwd.path(), "dir/log.md"))
    for entry in log_entries {
      formatter.format_log_entry(entry)
    }
    inspect(
      formatter.to_string(),
      content=(
        #|## 🤖 Spawned subagent for tool: <meta_write_to_file>
        #|
        #|[<meta_write_to_file> log](log.md-d9a50da2-c4d2-4177-8af4-f6a38d284e49.md)
        #|
      ),
    )
    inspect(
      formatter.tools.values().collect().map(tool => tool.to_string())[0],
      content=(
        #|# 1 User: You are a MoonBit syntax fixing assistant. A file has been written but contains syntax errors that need to be fixed.
        #|
        #|You are a MoonBit syntax fixing assistant. A file has been written but contains syntax errors that need to be fixed.
        #|
        #|
        #|**Task Description:**
        #|
        #|Create JSON lexer implementation
        #|
        #|**File Content:**
        #|
        #|```moonbit
        #|///|
        #|/// JSON lexer for tokenizing input strings
        #|struct Lexer {
        #|  input : String
        #|  position : Int
        #|  read_position : Int
        #|  ch : Char?
        #|}
        #|
        #|///|
        #|fn new_lexer(input : String) -> Lexer {
        #|  let lexer = { input, position: 0, read_position: 0, ch: None }
        #|  read_char(lexer)
        #|  lexer
        #|}
        #|```
        #|
        #|**Current Syntax Errors:**
        #|
        #|error[3002]: lexer.mbt: Parse error, unexpected token `}`, you may expect `{`.
        #| 45 │ }
        #|    │ ^
        #|
        #|error[3002]: lexer.mbt: Parse error, unexpected token .., you may expect `,`, `:` or `)`.
        #| 87 │       Some(ch) if ch is ('0'..'9' | '.' | '-' | '+' | 'e' | 'E') => {
        #|    │                             ^^
        #|
        #|error[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.
        #| 94 │   }
        #|    │    
        #|
        #|error[3002]: lexer.mbt: Parse error, unexpected token `}`, you may expect `{`.
        #| 130 │ }
        #|     │ ^
        #|
        #|error[3002]: lexer.mbt: Parse error, unexpected token .., you may expect `,`, `:` or `)`.
        #| 137 │       Some(ch) if ch is ('a'..'z' | 'A'..'Z' | '_') => {
        #|     │                             ^^
        #|
        #|error[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.
        #| 144 │   }
        #|     │    
        #|
        #|error[3002]: lexer.mbt: Parse error, unexpected token `?`, you may expect `;` or `}`.
        #| 189 │           read_string(lexer)?
        #|     │                             ^
        #|
        #|error[3002]: lexer.mbt: Parse error, unexpected token .., you may expect `=>`.
        #| 191 │         '0'..'9' | '-' => {
        #|     │            ^^
        #|
        #|error[3002]: lexer.mbt: Parse error, unexpected token character, you may expect id (lowercase start).
        #| 194 │         'a'..'z' | 'A'..'Z' | '_' => {
        #|     │              ^^^
        #|
        #|error[3002]: lexer.mbt: Parse error, unexpected token id (uppercase start), you may expect `pub`, `priv`, `type`, `suberror`, `typealias`, `async`, `fn`, `fnalias`, `struct`, `enum`, `let`, `const`, `extern`, `test`, `impl`, `trait`, `traitalias`, `enumview`, `#attribute` or `using`.
        #| 203 │     None => {
        #|     │     ^^^^
        #|
        #|**Your Task:**
        #|
        #|1. Analyze the syntax errors and understand what needs to be fixed
        #|2. Use `submit_fixed_file` to provide the complete fixed file content
        #|3. Only fix syntax errors - do not change logic unless absolutely necessary
        #|4. Continue until all syntax errors are fixed
        #|5. Call `attempt_completion` when done
        #|
        #|**Guidelines:**
        #|
        #|- Focus only on fixing syntax errors, not improving code quality
        #|- Preserve the original intent and functionality of the code, as much as possible
        #|- Use proper MoonBit syntax and conventions
        #|- If you cannot fix an error, explain why clearly
        #|- When syntax check passes, call `attempt_completion` immediately
        #|
        #|# 2 ❌ Tool call error: <submit_fixed_file>
        #|
        #|````markdown
        #|File verification failed with syntax errors:
        #|error[3002]: lexer.mbt: Parse error, unexpected token `}`, you may expect `{`.
        #| 45 │ }
        #|    │ ^
        #|
        #|error[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.
        #| 103 │   }
        #|     │    
        #|
        #|error[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.
        #| 139 │   }
        #|     │    
        #|
        #|error[3002]: lexer.mbt: Unexpected line break here, missing `{` at the end of this line.
        #| 159 │   }
        #|     │    
        #|````
        #|
      ),
    )
  })
}

///|
async test "timestamp" {
  let entries : Array[Json] = [
    {
      "level": 30,
      "pid": 92341,
      "msg": "ModelLoaded",
      "hostname": "Haoxiangs-MacBook-Pro.local",
      "time": 1762239992779,
      "tag": "maria_test",
      "name": ["qwen/qwen3-coder-plus"],
      "model": [
        {
          "name": "qwen/qwen3-coder-plus",
          "description": "Qwen coder",
          "model_name": "qwen/qwen3-coder-plus",
          "model_type": "saas/openai",
          "api_key": "sk-test",
          "base_url": "https://openrouter.ai/api/v1",
          "safe_zone_tokens": 256000,
          "supports_anthropic_prompt_caching": false,
        },
      ],
    },
    {
      "level": 30,
      "pid": 92341,
      "msg": "PostToolCall",
      "hostname": "Haoxiangs-MacBook-Pro.local",
      "time": 1762240682834,
      "tag": "maria_test",
      "tool_call": {
        "id": "call_10c97dd001b24eb9ad869657",
        "function": {
          "name": "meta_write_to_file",
          "arguments": "{\"path\": \"toml_parser/src/moon.pkg.json\", \"replace\": \"{\\n  \\\"import\\\": []\\n}\", \"description\": \"Updating the package configuration\"}",
        },
        "type": "function",
      },
      "name": "meta_write_to_file",
      "result": {
        "path": "toml_parser/src/moon.pkg.json",
        "message": "File written successfully to toml_parser/src/moon.pkg.json",
        "diff": "",
      },
      "text": "File written successfully to toml_parser/src/moon.pkg.json\n",
    },
  ]
  let formatter = Formatter::new("test.md")
  for entry in entries {
    formatter.format_log_entry(entry)
  }
  inspect(
    formatter.to_string(),
    content=(
      #|# System information
      #|
      #|00:00:00
      #|
      #|Model: qwen/qwen3-coder-plus
      #|
      #|# 1 Tool call result: <meta_write_to_file path="toml_parser/src/moon.pkg.json">
      #|
      #|00:11:30
      #|
      #|````markdown
      #|File written successfully to toml_parser/src/moon.pkg.json
      #|
      #|````
      #|
    ),
  )
}

///|
async test "should_properly_quote_system_message" {
  let log_entry : Json = {
    "msg": "MessageAdded",
    "message": {
      "role": "system",
      "content": [
        {
          "type": "text",
          "text": (
            #|````markdown
            #|You are a helpful assistant that helps users write MoonBit code.
            #|
            #|```moonbit
            #|///|
            #|fn main {
            #|  println("Hello, MoonBit!")
            #|}
            #|```
            #|````
          ),
        },
      ],
    },
  }
  let formatter = Formatter::new("test.md")
  formatter.format_log_entry(log_entry)
  inspect(
    formatter.to_string(),
    content=(
      #|# 1 System
      #|
      #|`````markdown
      #|````markdown
      #|You are a helpful assistant that helps users write MoonBit code.
      #|
      #|```moonbit
      #|///|
      #|fn main {
      #|  println("Hello, MoonBit!")
      #|}
      #|```
      #|````
      #|`````
      #|
    ),
  )
}
