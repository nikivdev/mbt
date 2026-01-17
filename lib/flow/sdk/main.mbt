///|
async fn @stdio.Output::writeln(self : @stdio.Output, str : String) -> Unit {
  self.write(str + "\n")
}

///|
async fn execute(prompt~ : String, model? : String) -> Unit {
  try {
    let maria = @maria.Maria::new(model?)
    maria.agent.add_listener(event => match event {
      ToolAdded(desc) => {
        let response : Json = {
          "method": "maria.agent.tool_added",
          "params": { "tool": desc.to_json() },
        }
        @stdio.stdout.writeln(response.stringify())
      }
      MessageAdded(message) => {
        let response : Json = {
          "method": "maria.agent.message_added",
          "params": { "message": message.to_json() },
        }
        @stdio.stdout.writeln(response.stringify())
      }
      PreConversation => {
        let response : Json = {
          "method": "maria.agent.conversation_start",
          "params": {},
        }
        @stdio.stdout.writeln(response.stringify())
      }
      PostConversation => {
        let response : Json = {
          "method": "maria.agent.conversation_end",
          "params": {},
        }
        @stdio.stdout.writeln(response.stringify())
      }
      RequestCompleted(usage~, message~) => {
        let response : Json = {
          "method": "maria.agent.request_completed",
          "params": { "usage": usage.to_json(), "message": message.to_json() },
        }
        @stdio.stdout.writeln(response.stringify())
      }
      PostToolCall(tool_call, result~, rendered~) => {
        let response : Json = {
          "method": "maria.agent.post_tool_call",
          "params": {
            "tool_call": tool_call.to_json(),
            "json": result.to_json(),
            "text": rendered.to_json(),
          },
        }
        @stdio.stdout.writeln(response.stringify())
      }
      _ => ()
    })
    maria.start(prompt)
  } catch {
    @io.ReaderClosed => ()
    error => {
      let error : Json = {
        "error": { "code": -1, "message": error.to_string() },
      }
      println(error.stringify())
    }
  }
}

///|
async fn main {
  @backtrace.initialize()
  let args = @os.args()
  let mut prompt = None
  let mut model = None
  loop args[1:] {
    ["exec" | "execute" | "-p" | "--prompt", p, .. args] =>
      if p.has_prefix("-") {
        let error : Json = {
          "error": {
            "code": -1,
            "message": Failure("Expect <prompt> after -p/--prompt").to_string(),
          },
        }
        println(error.stringify())
      } else {
        prompt = Some(p)
        continue args
      }
    ["-m" | "--model", m, .. args] =>
      if m.has_prefix("-") {
        let error : Json = {
          "error": {
            "code": -1,
            "message": Failure("Expect <model> after -m/--model").to_string(),
          },
        }
        println(error.stringify())
      } else {
        model = Some(m)
        continue args
      }
    [unknown, ..] => {
      let error : Json = {
        "error": {
          "code": -1,
          "message": Failure("Unknown argument: \{unknown}").to_string(),
        },
      }
      println(error.stringify())
    }
    [] => break
  }
  guard prompt is Some(prompt) else {
    let error : Json = {
      "error": {
        "code": -1,
        "message": Failure("Missing required argument: -p/--prompt <prompt>").to_string(),
      },
    }
    println(error.stringify())
    return
  }
  execute(prompt~, model?)
}
