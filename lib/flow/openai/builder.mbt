///|
priv struct ChatCompletionMessageToolCallBuilder {
  id : String
  name : String
  arguments : StringBuilder
}

///|
fn ChatCompletionMessageToolCallBuilder::new(
  id~ : String,
  name~ : String,
) -> ChatCompletionMessageToolCallBuilder {
  ChatCompletionMessageToolCallBuilder::{
    id,
    name,
    arguments: StringBuilder::new(),
  }
}

///|
fn ChatCompletionMessageToolCallBuilder::add_delta(
  self : ChatCompletionMessageToolCallBuilder,
  delta : ChatCompletionChunkChoiceDeltaToolCall,
) -> Unit {
  if delta.function.arguments is Some(arguments) {
    self.arguments.write_string(arguments)
  }
}

///|
fn ChatCompletionMessageToolCallBuilder::to_tool_call(
  self : ChatCompletionMessageToolCallBuilder,
) -> ChatCompletionMessageToolCall {
  tool_call(id=self.id, name=self.name, arguments=self.arguments.to_string())
}

///|
priv struct ChatCompletionMessageBuilder {
  mut content : StringBuilder?
  mut refusal : StringBuilder?
  tool_calls : Array[ChatCompletionMessageToolCallBuilder?]
}

///|
fn ChatCompletionMessageBuilder::new() -> ChatCompletionMessageBuilder {
  ChatCompletionMessageBuilder::{ content: None, refusal: None, tool_calls: [] }
}

///|
fn ChatCompletionMessageBuilder::add_delta(
  self : ChatCompletionMessageBuilder,
  delta : ChatCompletionChunkChoiceDelta,
) -> Unit {
  if delta.content is Some(content) {
    if self.content is Some(builder) {
      builder.write_string(content)
    } else {
      let builder = StringBuilder::new()
      builder.write_string(content)
      self.content = Some(builder)
    }
  }
  if delta.refusal is Some(refusal) {
    if self.refusal is Some(builder) {
      builder.write_string(refusal)
    } else {
      let builder = StringBuilder::new()
      builder.write_string(refusal)
      self.refusal = Some(builder)
    }
  }
  if delta.tool_calls is Some(tool_calls) {
    for tool_call in tool_calls {
      let builder = if self.tool_calls.get(tool_call.index)
        is Some(Some(builder)) {
        builder
      } else {
        let builder = ChatCompletionMessageToolCallBuilder::new(
          id=tool_call.id.unwrap(),
          name=tool_call.function.name.unwrap(),
        )
        if tool_call.index >= self.tool_calls.length() {
          self.tool_calls.resize(tool_call.index + 1, None)
        }
        self.tool_calls[tool_call.index] = Some(builder)
        builder
      }
      builder.add_delta(tool_call)
    }
  }
}

///|
fn ChatCompletionMessageBuilder::to_message(
  self : ChatCompletionMessageBuilder,
) -> ChatCompletionMessage {
  let tool_calls : Array[ChatCompletionMessageToolCall] = []
  for builder in self.tool_calls {
    guard builder is Some(builder) else { continue }
    tool_calls.push(builder.to_tool_call())
  }
  ChatCompletionMessage::{
    content: self.content.map(b => b.to_string()),
    refusal: self.refusal.map(b => b.to_string()),
    tool_calls,
    role: ChatCompletionMessageRole::Assistant,
  }
}

///|
priv struct ChatCompletionChoiceBuilder {
  mut finish_reason : ChatCompletionChoiceFinishReason?
  index : Int
  message : ChatCompletionMessageBuilder
}

///|
fn ChatCompletionChoiceBuilder::new(index : Int) -> ChatCompletionChoiceBuilder {
  ChatCompletionChoiceBuilder::{
    finish_reason: None,
    index,
    message: ChatCompletionMessageBuilder::new(),
  }
}

///|
fn ChatCompletionChoiceBuilder::add_chunk(
  self : ChatCompletionChoiceBuilder,
  chunk : ChatCompletionChunkChoice,
) -> Unit {
  if chunk.finish_reason is Some(reason) {
    self.finish_reason = Some(reason)
  }
  self.message.add_delta(chunk.delta)
}

///|
fn ChatCompletionChoiceBuilder::to_choice(
  self : ChatCompletionChoiceBuilder,
) -> ChatCompletionChoice {
  ChatCompletionChoice::{
    finish_reason: self.finish_reason,
    index: self.index,
    message: self.message.to_message(),
    logprobs: None,
  }
}

///|
priv struct ChatCompletionBuilder {
  mut id : String?
  choices : Array[ChatCompletionChoiceBuilder?]
  mut created : Int?
  mut model : String?
  mut usage : CompletionUsage?
  mut system_fingerprint : String?
  mut service_tier : ChatCompletionServiceTier?
  mut error : OpenRouterErrorResponse?
}

///|
fn ChatCompletionBuilder::new() -> ChatCompletionBuilder {
  ChatCompletionBuilder::{
    id: None,
    choices: [],
    created: None,
    model: None,
    usage: None,
    system_fingerprint: None,
    service_tier: None,
    error: None,
  }
}

///|
fn ChatCompletionBuilder::add_chunk(
  self : ChatCompletionBuilder,
  chunk : ChatCompletionChunk,
) -> Unit {
  if self.id is None {
    self.id = Some(chunk.id)
  }
  if self.created is None {
    self.created = Some(chunk.created)
  }
  if self.model is None {
    self.model = Some(chunk.model)
  }
  if self.usage is None && chunk.usage is Some(_) {
    self.usage = chunk.usage
  }
  if self.system_fingerprint is None && chunk.system_fingerprint is Some(_) {
    self.system_fingerprint = chunk.system_fingerprint
  }
  if self.service_tier is None && chunk.service_tier is Some(_) {
    self.service_tier = chunk.service_tier
  }
  if self.error is None && chunk.error is Some(_) {
    self.error = chunk.error
  }
  for choice_chunk in chunk.choices {
    let index = choice_chunk.index
    let builder = if self.choices.get(index) is Some(Some(builder)) {
      builder
    } else {
      let builder = ChatCompletionChoiceBuilder::new(index)
      if index >= self.choices.length() {
        self.choices.resize(index + 1, None)
      }
      self.choices[index] = Some(builder)
      builder
    }
    builder.add_chunk(choice_chunk)
  }
}

///|
fn ChatCompletionBuilder::to_chat_completion(
  self : ChatCompletionBuilder,
) -> ChatCompletion {
  ChatCompletion::{
    id: self.id.unwrap(),
    choices: self.choices
    .iter()
    .filter_map(builder => builder.map(b => b.to_choice()))
    .to_array(),
    created: self.created.unwrap(),
    model: self.model.unwrap(),
    usage: self.usage,
    system_fingerprint: self.system_fingerprint,
    service_tier: self.service_tier,
  }
}
