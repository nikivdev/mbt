///|
pub async fn interactive(args : ArrayView[String]) -> Unit {
  let mut prompt : String? = None
  let mut model : String? = None
  loop args {
    ["--prompt" | "-p", value, .. rest] => {
      prompt = Some(value)
      continue rest
    }
    ["--model" | "-m", value, .. rest] => {
      model = Some(value)
      continue rest
    }
    [unknown, ..] => raise @argument.InvalidArgument(unknown)
    [] => break
  }
  @async.with_task_group(group => {
    let maria = @maria.Maria::new(model?)
    maria.agent.add_listener(event => match event {
      RequestCompleted(message~, ..) => {
        guard message.content is Some(content) else { return }
        println(content)
      }
      PreToolCall(tool_call) =>
        match tool_call.function.arguments {
          None => println("% \{tool_call.function.name}")
          Some(arguments) =>
            try {
              let arguments = @json.parse(arguments)
              println(
                "% \{tool_call.function.name} \{arguments.stringify(indent=2)}",
              )
            } catch {
              _ => println("% \{tool_call.function.name}\n  \{arguments}")
            }
        }
      PostToolCall(_, rendered~, ..) =>
        rendered.split("\n").each(text => println("> \{text}"))
      _ => ()
    })
    let rl = @readline.interface(input=@stdio.stdin, output=@stdio.stdout)
    group.spawn_bg(() => rl.start())
    if prompt is Some(prompt) {
      println("$ \{prompt}")
      maria.start(prompt)
    }
    while true {
      rl.set_prompt("$ ")
      rl.prompt()
      let prompt = rl.read_line()
      maria.start(prompt)
    }
  })
}
