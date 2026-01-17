///|
pub async fn list() -> Unit {
  let cwd = @os.cwd()
  let uuid = @uuid.generator(@rand.chacha8())
  let manager = @conv.Manager::new(uuid~, cwd~)
  for i, id in manager.list() {
    let conversation = manager.load(id)
    guard conversation is Some(conversation) else { continue }
    let lines = ["\{i + 1}. \{id}"]
    lines.append(conversation.display().map(line => "    \{line}"))
    println(lines.join("\n"))
  }
}

///|
pub async fn show(args : ArrayView[String]) -> Unit {
  let mut output : String? = None
  let id = match args {
    [id] => id
    [id, "--output", value] => {
      output = Some(value)
      id
    }
    [..] => raise @argument.InvalidArgument(args.join(" "))
  }
  let cwd = @os.cwd()
  let uuid = @uuid.generator(@rand.chacha8())
  let manager = @conv.Manager::new(uuid~, cwd~)
  let conversation = manager.load(id)
  guard conversation is Some(conversation) else { return }
  if output is Some(output) {
    if output.has_suffix(".md") {
      @fsx.write_to_file(output, conversation.export_to_markdown())
    }
  } else {
    let lines = conversation.display(show_messages=true)
    println(lines.join("\n"))
  }
}
