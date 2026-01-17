///|
/// TODO: add ChatCompletionMessageRole enum to openai package
fn openai_message_role(message : @openai.ChatCompletionMessageParam) -> String {
  match message {
    User(_) => "User"
    Assistant(_) => "Assistant"
    System(_) => "System"
    Tool(_) => "Tool"
  }
}

///|
/// TODO: move to openai package
fn openai_message_content(
  message : @openai.ChatCompletionMessageParam,
) -> String {
  match message {
    User(user_message) => {
      let builder = StringBuilder::new()
      for part in user_message.content {
        if part is Text(text) {
          builder.write_string(text.text)
        }
      }
      builder.to_string()
    }
    Assistant(assistant_message) => {
      let builder = StringBuilder::new()
      for part in assistant_message.content {
        if part is Text(text) {
          builder.write_string(text.text)
        }
      }
      builder.to_string()
    }
    System(system_message) => {
      let builder = StringBuilder::new()
      for part in system_message.content {
        if part is Text(text) {
          builder.write_string(text.text)
        }
      }
      builder.to_string()
    }
    Tool(tool_message) => {
      let builder = StringBuilder::new()
      for part in tool_message.content {
        if part is Text(text) {
          builder.write_string(text.text)
        }
      }
      builder.to_string()
    }
  }
}
