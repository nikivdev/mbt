///|
impl @json.FromJson for ChatCompletionServiceTier with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionServiceTier {
  guard json is String(tier) else {
    raise @json.JsonDecodeError((json_path, "Expected a string"))
  }
  match tier {
    "auto" => ChatCompletionServiceTier::Auto
    "default" => ChatCompletionServiceTier::Default
    "flex" => ChatCompletionServiceTier::Flex
    "scale" => ChatCompletionServiceTier::Scale
    "priority" => ChatCompletionServiceTier::Priority
    _ =>
      raise @json.JsonDecodeError((json_path, "Unknown service tier: \{tier}"))
  }
}

///|
impl ToJson for ChatCompletionServiceTier with to_json(
  self : ChatCompletionServiceTier,
) -> Json {
  match self {
    Auto => "auto"
    Default => "default"
    Flex => "flex"
    Scale => "scale"
    Priority => "priority"
  }
}

///|
impl @json.FromJson for ChatCompletionChoiceLogprobs with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionChoiceLogprobs {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  let content : Array[ChatCompletionTokenLogprob]? = match json.get("content") {
    Some(Null) => None
    Some(content) => {
      let content : Array[ChatCompletionTokenLogprob] = @json.from_json(
        content,
        path=json_path.add_key("content"),
      )
      Some(content)
    }
    None => None
  }
  let refusal : Array[ChatCompletionTokenLogprob]? = match json.get("refusal") {
    Some(Null) => None
    Some(refusal) => {
      let refusal : Array[ChatCompletionTokenLogprob] = @json.from_json(
        refusal,
        path=json_path.add_key("refusal"),
      )
      Some(refusal)
    }
    None => None
  }
  ChatCompletionChoiceLogprobs::{ content, refusal }
}

///|
impl ToJson for ChatCompletionChoiceLogprobs with to_json(
  self : ChatCompletionChoiceLogprobs,
) -> Json {
  let json : Map[String, Json] = {}
  if self.content is Some(content) {
    json["content"] = content.to_json()
  }
  if self.refusal is Some(refusal) {
    json["refusal"] = refusal.to_json()
  }
  Json::object(json)
}

///|
impl ToJson for ChatCompletionTokenLogprob with to_json(
  self : ChatCompletionTokenLogprob,
) -> Json {
  let json : Map[String, Json] = {
    "token": Json::string(self.token),
    "logprob": self.logprob.to_json(),
  }
  if self.bytes is Some(bytes) {
    json["bytes"] = bytes.to_json()
  }
  json["top_logprobs"] = self.top_logprobs.to_json()
  Json::object(json)
}

///|
impl @json.FromJson for ChatCompletionTokenLogprob with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionTokenLogprob {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("token") is Some(String(token)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'token' field"))
  }
  guard json.get("logprob") is Some(Number(logprob, ..)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'logprob' field"))
  }
  let bytes = match json.get("bytes") {
    Some(Null) => None
    Some(bytes) => {
      let bytes : Array[Int] = @json.from_json(
        bytes,
        path=json_path.add_key("bytes"),
      )
      Some(bytes)
    }
    None => None
  }
  guard json.get("top_logprobs") is Some(top_logprobs) else {
    raise @json.JsonDecodeError((json_path, "Missing 'top_logprobs' field"))
  }
  let top_logprobs : Array[ChatCompletionTopLogprob] = @json.from_json(
    top_logprobs,
    path=json_path.add_key("top_logprobs"),
  )
  ChatCompletionTokenLogprob::{ token, logprob, bytes, top_logprobs }
}

///|
impl @json.FromJson for ChatCompletionTopLogprob with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionTopLogprob {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("token") is Some(String(token)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'token' field"))
  }
  guard json.get("logprob") is Some(Number(logprob, ..)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'logprob' field"))
  }
  let bytes = match json.get("bytes") {
    Some(Null) => None
    Some(bytes) => {
      let bytes : Array[Int] = @json.from_json(
        bytes,
        path=json_path.add_key("bytes"),
      )
      Some(bytes)
    }
    None => None
  }
  ChatCompletionTopLogprob::{ token, logprob, bytes }
}

///|
impl ToJson for ChatCompletionTopLogprob with to_json(
  self : ChatCompletionTopLogprob,
) -> Json {
  let json : Map[String, Json] = {
    "token": Json::string(self.token),
    "logprob": self.logprob.to_json(),
  }
  if self.bytes is Some(bytes) {
    json["bytes"] = bytes.to_json()
  }
  Json::object(json)
}

///|
impl ToJson for ChatCompletionMessageToolCallFunction with to_json(
  self : ChatCompletionMessageToolCallFunction,
) -> Json {
  { "name": self.name, "arguments": self.arguments.unwrap_or("") }
}

///|
impl @json.FromJson for ChatCompletionMessageToolCallFunction with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionMessageToolCallFunction {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  let arguments = match json.get("arguments") {
    Some(String(arguments)) => Some(arguments)
    Some(Null) => None
    Some(_) =>
      raise @json.JsonDecodeError(
        (json_path, "Expected 'arguments' to be a string"),
      )
    None => None
  }
  guard json.get("name") is Some(String(name)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'name' field"))
  }
  ChatCompletionMessageToolCallFunction::{ arguments, name }
}

///|
pub impl ToJson for ChatCompletionMessageToolCall with to_json(
  self : ChatCompletionMessageToolCall,
) -> Json {
  { "id": self.id, "function": self.function, "type": "function" }
}

///|
impl @json.FromJson for ChatCompletionMessageToolCall with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionMessageToolCall {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("id") is Some(String(id)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'id' field"))
  }
  guard json.get("function") is Some(function) else {
    raise @json.JsonDecodeError((json_path, "Missing 'function' field"))
  }
  let function : ChatCompletionMessageToolCallFunction = @json.from_json(
    function,
    path=json_path.add_key("function"),
  )
  ChatCompletionMessageToolCall::{ id, function }
}

///|
pub impl ToJson for ChatCompletionMessageRole with to_json(
  self : ChatCompletionMessageRole,
) -> Json {
  match self {
    Assistant => "assistant"
  }
}

///|
pub fn ChatCompletionMessage::to_param(
  self : ChatCompletionMessage,
) -> ChatCompletionMessageParam {
  let parts = []
  if self.content is Some(content) {
    parts.push(text_content_part(content))
  }
  Assistant({ content: parts, name: None, tool_calls: self.tool_calls })
}

///|
pub impl @json.FromJson for ChatCompletionMessage with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionMessage {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  let content = match json.get("content") {
    Some(Null) => None
    Some(content) => {
      let content : String = @json.from_json(
        content,
        path=json_path.add_key("content"),
      )
      Some(content)
    }
    None => None
  }
  let refusal = match json.get("refusal") {
    Some(Null) => None
    Some(refusal) => {
      let refusal : String = @json.from_json(
        refusal,
        path=json_path.add_key("refusal"),
      )
      Some(refusal)
    }
    None => None
  }
  let tool_calls = match json.get("tool_calls") {
    Some(tool_calls) => {
      let tool_calls : Array[ChatCompletionMessageToolCall] = @json.from_json(
        tool_calls,
        path=json_path.add_key("tool_calls"),
      )
      tool_calls
    }
    None => []
  }
  ChatCompletionMessage::{ content, refusal, role: Assistant, tool_calls }
}

///|
impl ToJson for ChatCompletionChoiceFinishReason with to_json(
  self : ChatCompletionChoiceFinishReason,
) -> Json {
  match self {
    Stop => "stop"
    Length => "length"
    ToolCalls => "tool_calls"
    ContentFilter => "content_filter"
    FunctionCall => "function_call"
  }
}

///|
impl @json.FromJson for ChatCompletionChoiceFinishReason with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionChoiceFinishReason {
  guard json is String(reason) else {
    raise @json.JsonDecodeError((json_path, "Expected a string"))
  }
  match reason {
    "stop" => ChatCompletionChoiceFinishReason::Stop
    "length" => ChatCompletionChoiceFinishReason::Length
    "tool_calls" => ChatCompletionChoiceFinishReason::ToolCalls
    "content_filter" => ChatCompletionChoiceFinishReason::ContentFilter
    "function_call" => ChatCompletionChoiceFinishReason::FunctionCall
    _ =>
      raise @json.JsonDecodeError(
        (json_path, "Unknown finish reason: \{reason}"),
      )
  }
}

///|
impl ToJson for ChatCompletionChoice with to_json(self : ChatCompletionChoice) -> Json {
  let json : Map[String, Json] = {
    "index": self.index.to_json(),
    "message": self.message.to_json(),
  }
  if self.finish_reason is Some(finish_reason) {
    json["finish_reason"] = finish_reason.to_json()
  }
  if self.logprobs is Some(logprobs) {
    json["logprobs"] = logprobs.to_json()
  }
  Json::object(json)
}

///|
impl @json.FromJson for ChatCompletionChoice with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionChoice {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  let finish_reason = match json.get("finish_reason") {
    Some(Null) => None
    Some(finish_reason) => {
      let finish_reason : ChatCompletionChoiceFinishReason = @json.from_json(
        finish_reason,
        path=json_path.add_key("finish_reason"),
      )
      Some(finish_reason)
    }
    None => None
  }
  guard json.get("index") is Some(Number(index, ..)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'index' field"))
  }
  guard json.get("message") is Some(message) else {
    raise @json.JsonDecodeError((json_path, "Missing 'message' field"))
  }
  let message : ChatCompletionMessage = @json.from_json(
    message,
    path=json_path.add_key("message"),
  )
  let logprobs = match json.get("logprobs") {
    Some(Null) => None
    Some(logprobs) => {
      let logprobs : ChatCompletionChoiceLogprobs = @json.from_json(
        logprobs,
        path=json_path.add_key("logprobs"),
      )
      Some(logprobs)
    }
    None => None
  }
  ChatCompletionChoice::{
    finish_reason,
    index: index.to_int(),
    message,
    logprobs,
  }
}

///|
impl @json.FromJson for CompletionTokensDetails with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> CompletionTokensDetails {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  let reasoning_tokens = match json.get("reasoning_tokens") {
    Some(Null) => None
    Some(Number(reasoning_tokens, ..)) => Some(reasoning_tokens.to_int())
    Some(_) =>
      raise @json.JsonDecodeError(
        (json_path, "Expected 'reasoning_tokens' to be a number"),
      )
    None => None
  }
  CompletionTokensDetails::{ reasoning_tokens, }
}

///|
impl @json.FromJson for CostDetails with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> CostDetails {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  let upstream_inference_cost = match json.get("upstream_inference_cost") {
    Some(Null) => None
    Some(Number(upstream_inference_cost, ..)) => Some(upstream_inference_cost)
    Some(_) =>
      raise @json.JsonDecodeError(
        (json_path, "Expected 'upstream_inference_cost' to be a number"),
      )
    None => None
  }
  CostDetails::{ upstream_inference_cost, }
}

///|
impl @json.FromJson for PromptTokensDetails with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> PromptTokensDetails {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  let cached_tokens = match json.get("cached_tokens") {
    Some(Null) => None
    Some(Number(cached_tokens, ..)) => Some(cached_tokens.to_int())
    Some(_) =>
      raise @json.JsonDecodeError(
        (json_path, "Expected 'cached_tokens' to be a number"),
      )
    None => None
  }
  let audio_tokens = match json.get("audio_tokens") {
    Some(Null) => None
    Some(Number(audio_tokens, ..)) => Some(audio_tokens.to_int())
    Some(_) =>
      raise @json.JsonDecodeError(
        (json_path, "Expected 'audio_tokens' to be a number"),
      )
    None => None
  }
  PromptTokensDetails::{ cached_tokens, audio_tokens }
}

///|
pub impl @json.FromJson for CompletionUsage with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> CompletionUsage {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("completion_tokens") is Some(Number(completion_tokens, ..)) else {
    raise @json.JsonDecodeError(
      (json_path, "Missing 'completion_tokens' field"),
    )
  }
  let completion_tokens_details = match json.get("completion_tokens_details") {
    Some(Null) => None
    Some(details) => {
      let details : CompletionTokensDetails = @json.from_json(
        details,
        path=json_path.add_key("completion_tokens_details"),
      )
      Some(details)
    }
    None => None
  }
  let cost = match json.get("cost") {
    Some(Null) => None
    Some(Number(cost, ..)) => Some(cost)
    Some(_) =>
      raise @json.JsonDecodeError((json_path, "Expected 'cost' to be a number"))
    None => None
  }
  let cost_details = match json.get("cost_details") {
    Some(Null) => None
    Some(details) => {
      let details : CostDetails = @json.from_json(
        details,
        path=json_path.add_key("cost_details"),
      )
      Some(details)
    }
    None => None
  }
  guard json.get("prompt_tokens") is Some(Number(prompt_tokens, ..)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'prompt_tokens' field"))
  }
  let prompt_tokens_details = match json.get("prompt_tokens_details") {
    Some(Null) => None
    Some(details) => {
      let details : PromptTokensDetails = @json.from_json(
        details,
        path=json_path.add_key("prompt_tokens_details"),
      )
      Some(details)
    }
    None => None
  }
  guard json.get("total_tokens") is Some(Number(total_tokens, ..)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'total_tokens' field"))
  }
  CompletionUsage::{
    completion_tokens: completion_tokens.to_int(),
    completion_tokens_details,
    cost,
    cost_details,
    prompt_tokens: prompt_tokens.to_int(),
    prompt_tokens_details,
    total_tokens: total_tokens.to_int(),
  }
}

///|
/// Create a usage tracking parameter for chat completions.
///
/// Controls whether token usage information is included in the response.
///
/// Parameters:
/// - include_: Whether to include usage statistics in the response
///
/// Returns a CompletionUsageParam that can be passed to chat_completion.
pub fn usage(include_~ : Bool) -> CompletionUsageParam {
  CompletionUsageParam::{ include_, }
}

///|
impl ToJson for CompletionUsageParam with to_json(self : CompletionUsageParam) -> Json {
  { "include": Json::boolean(self.include_) }
}

///|
pub fn stream_options(
  include_obfuscation? : Bool,
  include_usage? : Bool,
) -> ChatCompletionStreamOptionsParam {
  ChatCompletionStreamOptionsParam::{ include_obfuscation, include_usage }
}

///|
pub impl ToJson for ChatCompletionStreamOptionsParam with to_json(
  self : ChatCompletionStreamOptionsParam,
) -> Json {
  let json : Map[String, Json] = {}
  if self.include_obfuscation is Some(include_obfuscation) {
    json["include_obfuscation"] = include_obfuscation.to_json()
  }
  if self.include_usage is Some(include_usage) {
    json["include_usage"] = include_usage.to_json()
  }
  Json::object(json)
}

///|
/// Create a chat completion parameter object.
///
/// This function constructs a complete set of parameters for a chat completion
/// request, including messages, tools, and various configuration options.
///
/// Parameters
///
/// - `model`: The model identifier (e.g., "gpt-4o-mini", "gpt-4-turbo")
/// - `messages`: Array of messages forming the conversation history
/// - `tools`: Optional array of function tools the model can call
/// - `usage`: Optional parameter to request usage statistics
/// - `user`: Optional unique identifier for the end-user
/// - `max_tokens`: Optional maximum number of tokens to generate
/// - `temperature`: Optional sampling temperature (0.0 to 2.0)
/// - `response_format`: Optional format for structured responses
///
/// Returns a ChatCompletionParam object ready to be passed to the chat function.
pub fn chat_completion(
  model~ : String,
  messages~ : Array[ChatCompletionMessageParam],
  tools? : Array[ChatCompletionToolParam] = [],
  usage? : CompletionUsageParam,
  user? : String,
  max_tokens? : Int,
  temperature? : Double,
  response_format? : ResponseFormat,
  stream? : Bool,
  stream_options? : ChatCompletionStreamOptionsParam,
  tool_choice? : ChatCompletionToolChoice,
) -> ChatCompletionParam {
  ChatCompletionParam::{
    model,
    messages,
    tools,
    usage,
    user,
    max_tokens,
    temperature,
    response_format,
    stream,
    stream_options,
    tool_choice,
  }
}

///|
pub impl ToJson for ChatCompletionParam with to_json(self : ChatCompletionParam) -> Json {
  let json : Map[String, Json] = {
    "model": Json::string(self.model),
    "messages": self.messages.to_json(),
  }
  if !self.tools.is_empty() {
    json["tools"] = self.tools.to_json()
  }
  if self.usage is Some(usage) {
    json["usage"] = usage.to_json()
  }
  if self.user is Some(user) {
    json["user"] = Json::string(user)
  }
  if self.max_tokens is Some(max_tokens) {
    json["max_tokens"] = max_tokens.to_json()
  }
  if self.temperature is Some(temperature) {
    json["temperature"] = temperature.to_json()
  }
  if self.response_format is Some(response_format) {
    json["response_format"] = response_format.to_json()
  }
  if self.stream is Some(stream) {
    json["stream"] = stream.to_json()
  }
  if self.stream_options is Some(stream_options) {
    json["stream_options"] = stream_options.to_json()
  }
  Json::object(json)
}

///|
pub impl ToJson for ChatCompletion with to_json(self : ChatCompletion) -> Json {
  let json : Map[String, Json] = {
    "id": Json::string(self.id),
    "choices": self.choices.to_json(),
    "created": self.created.to_json(),
    "model": Json::string(self.model),
  }
  if self.usage is Some(usage) {
    json["usage"] = usage.to_json()
  }
  if self.system_fingerprint is Some(fingerprint) {
    json["system_fingerprint"] = Json::string(fingerprint)
  }
  if self.service_tier is Some(service_tier) {
    json["service_tier"] = service_tier.to_json()
  }
  Json::object(json)
}

///|
pub impl @json.FromJson for ChatCompletion with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletion {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("id") is Some(String(id)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'id' field"))
  }
  guard json.get("choices") is Some(choices) else {
    raise @json.JsonDecodeError((json_path, "Missing 'choices' field"))
  }
  let choices : Array[ChatCompletionChoice] = @json.from_json(
    choices,
    path=json_path.add_key("choices"),
  )
  guard json.get("created") is Some(Number(created, ..)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'created' field"))
  }
  guard json.get("model") is Some(String(model)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'model' field"))
  }
  let usage = match json.get("usage") {
    Some(Null) => None
    Some(usage) => {
      let usage : CompletionUsage = @json.from_json(
        usage,
        path=json_path.add_key("usage"),
      )
      Some(usage)
    }
    None => None
  }
  let system_fingerprint = match json.get("system_fingerprint") {
    Some(Null) => None
    Some(String(fingerprint)) => Some(fingerprint)
    Some(_) =>
      raise @json.JsonDecodeError(
        (json_path, "Expected 'system_fingerprint' to be a string"),
      )
    None => None
  }
  let service_tier = match json.get("service_tier") {
    Some(Null) => None
    Some(service_tier) => {
      let service_tier : ChatCompletionServiceTier = @json.from_json(
        service_tier,
        path=json_path.add_key("service_tier"),
      )
      Some(service_tier)
    }
    None => None
  }
  ChatCompletion::{
    id,
    choices,
    created: created.to_int(),
    model,
    usage,
    system_fingerprint,
    service_tier,
  }
}

///|
pub impl ToJson for ChatCompletionContentPartParam with to_json(
  self : ChatCompletionContentPartParam,
) -> Json {
  match self {
    Text(param) => {
      let json : Map[String, Json] = {
        "type": "text",
        "text": param.text.to_json(),
      }
      if param.cache_control is Some(cache_control) {
        json["cache_control"] = cache_control.to_json()
      }
      Json::object(json)
    }
  }
}

///|
impl @json.FromJson for ChatCompletionContentPartParam with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionContentPartParam raise {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("type") is Some(String(type_)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'type' field"))
  }
  match type_ {
    "text" => {
      guard json.get("text") is Some(String(text)) else {
        raise @json.JsonDecodeError((json_path, "Missing 'text' field"))
      }
      let cache_control = match json.get("cache_control") {
        None | Some(Null) => None
        Some(cache_control) => {
          let cache_control : CacheControl = @json.from_json(
            cache_control,
            path=json_path.add_key("cache_control"),
          )
          Some(cache_control)
        }
      }
      ChatCompletionContentPartParam::Text(ChatCompletionContentPartTextParam::{
        text,
        cache_control,
      })
    }
    _ =>
      raise @json.JsonDecodeError(
        (json_path, "Unknown content part type: \{type_}"),
      )
  }
}

///|
/// Create a text content part for message content.
///
/// Text content parts are the building blocks of message content in chat completions.
/// They can optionally include cache control directives for prompt caching.
///
/// Parameters
/// - `text`: The text content
/// - `cache_control`: Optional cache control directive (currently only `Ephemeral` is supported)
///
/// Returns a `ChatCompletionContentPartParam` that can be included in message content
pub fn text_content_part(
  text : String,
  cache_control? : CacheControl,
) -> ChatCompletionContentPartParam {
  ChatCompletionContentPartParam::Text({ text, cache_control })
}

///|
pub impl ToJson for CacheControl with to_json(self : CacheControl) -> Json {
  match self {
    Ephemeral => { "type": "ephemeral" }
  }
}

///|
impl @json.FromJson for CacheControl with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> CacheControl {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("type") is Some(String(type_)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'type' field"))
  }
  match type_ {
    "ephemeral" => CacheControl::Ephemeral
    _ =>
      raise @json.JsonDecodeError(
        (json_path, "Unknown cache control type: \{type_}"),
      )
  }
}

///|
pub impl ToJson for ChatCompletionMessageParam with to_json(
  self : ChatCompletionMessageParam,
) {
  fn content_parts_to_json(
    content_parts : Array[ChatCompletionContentPartParam],
    json : Map[String, Json],
  ) -> Unit {
    match content_parts {
      [] => ()
      [Text(text)] if text.cache_control is None =>
        json["content"] = text.text.to_json()
      [.. parts] => json["content"] = parts.to_json()
    }
  }

  match self {
    System(param) => {
      let json : Map[String, Json] = { "role": "system" }
      content_parts_to_json(param.content, json)
      if param.name is Some(name) {
        json["name"] = Json::string(name)
      }
      Json::object(json)
    }
    User(param) => {
      let json : Map[String, Json] = { "role": "user" }
      content_parts_to_json(param.content, json)
      if param.name is Some(name) {
        json["name"] = Json::string(name)
      }
      Json::object(json)
    }
    Assistant(param) => {
      let json : Map[String, Json] = {
        "role": "assistant",
        "tool_calls": param.tool_calls.to_json(),
      }
      content_parts_to_json(param.content, json)
      if param.name is Some(name) {
        json["name"] = Json::string(name)
      }
      Json::object(json)
    }
    Tool(param) =>
      {
        "role": "tool",
        "content": param.content,
        "tool_call_id": param.tool_call_id,
      }
  }
}

///|
pub impl @json.FromJson for ChatCompletionMessageParam with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionMessageParam {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("role") is Some(String(role)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'role' field"))
  }
  match role {
    "user" => {
      guard json.get("content") is Some(content) else {
        raise @json.JsonDecodeError((json_path, "Missing 'content' field"))
      }
      let content : Array[ChatCompletionContentPartParam] = match content {
        String(text) => [text_content_part(text)]
        Array(_) as parts =>
          @json.from_json(parts, path=json_path.add_key("content"))
        _ =>
          raise @json.JsonDecodeError(
            (json_path, "Expected 'content' to be a string or array"),
          )
      }
      let name = match json.get("name") {
        None | Some(Null) => None
        Some(String(name)) => Some(name)
        Some(_) =>
          raise @json.JsonDecodeError(
            (json_path, "Expected 'name' to be a string"),
          )
      }
      ChatCompletionMessageParam::User({ content, name })
    }
    "assistant" => {
      guard json.get("content") is Some(content) else {
        raise @json.JsonDecodeError((json_path, "Missing 'content' field"))
      }
      let content : Array[ChatCompletionContentPartParam] = match content {
        String(text) => [text_content_part(text)]
        Array(_) as parts =>
          @json.from_json(parts, path=json_path.add_key("content"))
        _ =>
          raise @json.JsonDecodeError(
            (json_path, "Expected 'content' to be a string or array"),
          )
      }
      let name = match json.get("name") {
        None | Some(Null) => None
        Some(String(name)) => Some(name)
        Some(_) =>
          raise @json.JsonDecodeError(
            (json_path, "Expected 'name' to be a string"),
          )
      }
      guard json.get("tool_calls") is Some(tool_calls) else {
        raise @json.JsonDecodeError((json_path, "Missing 'tool_calls' field"))
      }
      let tool_calls : Array[ChatCompletionMessageToolCallParam] = @json.from_json(
        tool_calls,
        path=json_path.add_key("tool_calls"),
      )
      ChatCompletionMessageParam::Assistant({ content, name, tool_calls })
    }
    "system" => {
      guard json.get("content") is Some(content) else {
        raise @json.JsonDecodeError((json_path, "Missing 'content' field"))
      }
      let content : Array[ChatCompletionContentPartParam] = match content {
        String(text) => [text_content_part(text)]
        Array(_) as parts =>
          @json.from_json(parts, path=json_path.add_key("content"))
        _ =>
          raise @json.JsonDecodeError(
            (json_path, "Expected 'content' to be a string or array"),
          )
      }
      let name = match json.get("name") {
        None | Some(Null) => None
        Some(String(name)) => Some(name)
        Some(_) =>
          raise @json.JsonDecodeError(
            (json_path, "Expected 'name' to be a string"),
          )
      }
      ChatCompletionMessageParam::System({ content, name })
    }
    "tool" => {
      guard json.get("content") is Some(content) else {
        raise @json.JsonDecodeError((json_path, "Missing 'content' field"))
      }
      let content : Array[ChatCompletionContentPartParam] = match content {
        String(text) => [text_content_part(text)]
        Array(_) as parts =>
          @json.from_json(parts, path=json_path.add_key("content"))
        _ =>
          raise @json.JsonDecodeError(
            (json_path, "Expected 'content' to be a string or array"),
          )
      }
      guard json.get("tool_call_id") is Some(String(tool_call_id)) else {
        raise @json.JsonDecodeError((json_path, "Missing 'tool_call_id' field"))
      }
      ChatCompletionMessageParam::Tool({ content, tool_call_id })
    }
    _ => raise @json.JsonDecodeError((json_path, "Unknown role: \{role}"))
  }
}

///|
trait ToChatCompletionMessageParamContent {
  to_chat_completion_message_param_content(self : Self) -> Array[
    ChatCompletionContentPartParam,
  ]
}

///|
pub impl ToChatCompletionMessageParamContent for String with to_chat_completion_message_param_content(
  self : String,
) -> Array[ChatCompletionContentPartParam] {
  [text_content_part(self)]
}

///|
pub impl ToChatCompletionMessageParamContent for StringView with to_chat_completion_message_param_content(
  self : StringView,
) -> Array[ChatCompletionContentPartParam] {
  [text_content_part(self.to_string())]
}

///|
pub impl ToChatCompletionMessageParamContent for ChatCompletionContentPartParam with to_chat_completion_message_param_content(
  self : ChatCompletionContentPartParam,
) -> Array[ChatCompletionContentPartParam] {
  [self]
}

///|
pub impl[T : ToChatCompletionMessageParamContent] ToChatCompletionMessageParamContent for Array[
  T,
] with to_chat_completion_message_param_content(self : Array[T]) -> Array[
  ChatCompletionContentPartParam,
] {
  let parts = []
  for part in self {
    parts.append(part.to_chat_completion_message_param_content())
  }
  parts
}

///|
/// Create a system message for chat completion.
///
/// System messages set the behavior and context for the assistant. They are
/// typically placed at the beginning of the conversation.
///
/// Parameters
///
/// - `content`: The system message content
/// - `name`: Optional name to identify the message author
///
/// Returns a ChatCompletionMessageParam with role "system".
pub fn[T : ToChatCompletionMessageParamContent] system_message(
  content~ : T,
  name? : String,
) -> ChatCompletionMessageParam {
  System({ content: content.to_chat_completion_message_param_content(), name })
}

///|
/// Create a user message for chat completion.
///
/// User messages represent input from the end user in the conversation.
///
/// Parameters
///
/// - `content`: The user message content
/// - `name`: Optional name to identify the user
///
/// Returns a ChatCompletionMessageParam representing the user's input with role "user".
pub fn[T : ToChatCompletionMessageParamContent] user_message(
  content~ : T,
  name? : String,
) -> ChatCompletionMessageParam {
  User({ content: content.to_chat_completion_message_param_content(), name })
}

///|
/// Create a tool result message for chat completion.
///
/// Tool messages contain the results of function tool calls made by the assistant.
/// They must reference a specific tool call ID from a previous assistant message.
///
/// Parameters
///
/// - `content`: The tool execution result
/// - `tool_call_id`: The ID of the tool call this result corresponds to
///
/// Returns a ChatCompletionMessageParam with role "tool".
pub fn[T : ToChatCompletionMessageParamContent] tool_message(
  content~ : T,
  tool_call_id~ : String,
) -> ChatCompletionMessageParam {
  Tool({
    content: content.to_chat_completion_message_param_content(),
    tool_call_id,
  })
}

///|
impl ToJson for FunctionDefinition with to_json(self : FunctionDefinition) -> Json {
  let json : Map[String, Json] = {
    "name": Json::string(self.name),
    "description": Json::string(self.description),
    "parameters": self.parameters,
  }
  if self.strict is Some(bool) {
    json["strict"] = Json::boolean(bool)
  }
  Json::object(json)
}

///|
/// Create a function tool definition for chat completion.
///
/// Tools allow the model to call functions to perform actions or retrieve
/// information. The model will decide when and how to call these functions
/// based on the conversation context.
///
/// Parameters
///
/// - `name`: The name of the function tool
/// - `description`: A description of what the function does (helps the model decide when to call it)
/// - `parameters`: JSON schema describing the function's parameters
/// - `strict`: Optional flag to enable strict schema validation
///
/// Returns a ChatCompletionToolParam representing the function tool.
pub fn tool(
  name~ : String,
  description~ : String,
  parameters~ : Json,
  strict? : Bool,
) -> ChatCompletionToolParam {
  Function(FunctionDefinition::{ name, description, parameters, strict })
}

///|
pub impl ToJson for ChatCompletionToolParam with to_json(
  self : ChatCompletionToolParam,
) -> Json {
  match self {
    Function(function_definition) =>
      { "type": "function", "function": function_definition.to_json() }
  }
}

///|
impl @json.FromJson for ChatCompletionChunkChoiceDeltaToolCallFunction with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionChunkChoiceDeltaToolCallFunction {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  let arguments = match json.get("arguments") {
    None | Some(Null) => None
    Some(String(arguments)) => Some(arguments)
    Some(_) =>
      raise @json.JsonDecodeError(
        (json_path, "Expected 'arguments' to be a string"),
      )
  }
  let name = match json.get("name") {
    None | Some(Null) => None
    Some(String(name)) => Some(name)
    Some(_) =>
      raise @json.JsonDecodeError((json_path, "Expected 'name' to be a string"))
  }
  ChatCompletionChunkChoiceDeltaToolCallFunction::{ arguments, name }
}

///|
impl @json.FromJson for ChatCompletionChunkChoiceDeltaToolCall with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionChunkChoiceDeltaToolCall {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("index") is Some(Number(index, ..)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'index' field"))
  }
  let id = match json.get("id") {
    None | Some(Null) => None
    Some(String(id)) => Some(id)
    Some(_) =>
      raise @json.JsonDecodeError((json_path, "Expected 'id' to be a string"))
  }
  guard json.get("function") is Some(function) else {
    raise @json.JsonDecodeError((json_path, "Missing 'function' field"))
  }
  let function : ChatCompletionChunkChoiceDeltaToolCallFunction = @json.from_json(
    function,
    path=json_path.add_key("function"),
  )
  ChatCompletionChunkChoiceDeltaToolCall::{
    index: index.to_int(),
    id,
    function,
  }
}

///|
impl @json.FromJson for ChatCompletionRole with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionRole {
  guard json is String(role) else {
    raise @json.JsonDecodeError((json_path, "Expected a string"))
  }
  match role {
    "developer" => Developer
    "system" => System
    "user" => User
    "assistant" => Assistant
    "tool" => Tool
    role => raise @json.JsonDecodeError((json_path, "Unknown role: \{role}"))
  }
}

///|
impl @json.FromJson for ChatCompletionChunkChoiceDelta with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionChunkChoiceDelta {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  let content = match json.get("content") {
    Some(Null) => None
    Some(content) => {
      let content : String = @json.from_json(
        content,
        path=json_path.add_key("content"),
      )
      Some(content)
    }
    None => None
  }
  let refusal = match json.get("refusal") {
    Some(Null) => None
    Some(refusal) => {
      let refusal : String = @json.from_json(
        refusal,
        path=json_path.add_key("refusal"),
      )
      Some(refusal)
    }
    None => None
  }
  let role = match json.get("role") {
    Some(role) => {
      let role : ChatCompletionRole = @json.from_json(
        role,
        path=json_path.add_key("role"),
      )
      Some(role)
    }
    None => None
  }
  let tool_calls = match json.get("tool_calls") {
    Some(tool_calls) => {
      let tool_calls : Array[ChatCompletionChunkChoiceDeltaToolCall] = @json.from_json(
        tool_calls,
        path=json_path.add_key("tool_calls"),
      )
      Some(tool_calls)
    }
    None => None
  }
  ChatCompletionChunkChoiceDelta::{ content, refusal, role, tool_calls }
}

///|
impl @json.FromJson for ChatCompletionChunkChoice with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionChunkChoice {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("index") is Some(Number(index, ..)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'index' field"))
  }
  guard json.get("delta") is Some(delta) else {
    raise @json.JsonDecodeError((json_path, "Missing 'delta' field"))
  }
  let delta : ChatCompletionChunkChoiceDelta = @json.from_json(
    delta,
    path=json_path.add_key("delta"),
  )
  let finish_reason = match json.get("finish_reason") {
    Some(Null) => None
    Some(finish_reason) => {
      let finish_reason : ChatCompletionChoiceFinishReason = @json.from_json(
        finish_reason,
        path=json_path.add_key("finish_reason"),
      )
      Some(finish_reason)
    }
    None => None
  }
  ChatCompletionChunkChoice::{ index: index.to_int(), delta, finish_reason }
}

///|
pub struct OpenRouterErrorResponse {
  code : Int
  message : String
  metadata : Json
} derive(ToJson)

///|
pub impl @json.FromJson for OpenRouterErrorResponse with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> OpenRouterErrorResponse {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("code") is Some(Number(code, ..)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'code' field"))
  }
  guard json.get("message") is Some(String(message)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'message' field"))
  }
  guard json.get("metadata") is Some(metadata) else {
    raise @json.JsonDecodeError((json_path, "Missing 'metadata' field"))
  }
  OpenRouterErrorResponse::{ code: code.to_int(), message, metadata }
}

///|
pub struct ChatCompletionChunk {
  id : String
  choices : Array[ChatCompletionChunkChoice]
  created : Int
  model : String
  usage : CompletionUsage?
  system_fingerprint : String?
  service_tier : ChatCompletionChunkServiceTier?
  error : OpenRouterErrorResponse?
} derive(ToJson)

///|
pub impl @json.FromJson for ChatCompletionChunk with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> ChatCompletionChunk {
  guard json is Object(json) else {
    raise @json.JsonDecodeError((json_path, "Expected an object"))
  }
  guard json.get("id") is Some(String(id)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'id' field"))
  }
  guard json.get("choices") is Some(choices) else {
    raise @json.JsonDecodeError((json_path, "Missing 'choices' field"))
  }
  let choices : Array[ChatCompletionChunkChoice] = @json.from_json(
    choices,
    path=json_path.add_key("choices"),
  )
  guard json.get("created") is Some(Number(created, ..)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'created' field"))
  }
  guard json.get("model") is Some(String(model)) else {
    raise @json.JsonDecodeError((json_path, "Missing 'model' field"))
  }
  let usage = match json.get("usage") {
    Some(Null) => None
    Some(usage) => {
      let usage : CompletionUsage = @json.from_json(
        usage,
        path=json_path.add_key("usage"),
      )
      Some(usage)
    }
    None => None
  }
  let system_fingerprint = match json.get("system_fingerprint") {
    Some(Null) => None
    Some(String(fingerprint)) => Some(fingerprint)
    Some(_) =>
      raise @json.JsonDecodeError(
        (json_path, "Expected 'system_fingerprint' to be a string"),
      )
    None => None
  }
  let service_tier = match json.get("service_tier") {
    Some(Null) => None
    Some(service_tier) => {
      let service_tier : ChatCompletionChunkServiceTier = @json.from_json(
        service_tier,
        path=json_path.add_key("service_tier"),
      )
      Some(service_tier)
    }
    None => None
  }
  let error = match json.get("error") {
    Some(Null) => None
    Some(error) => {
      let error : OpenRouterErrorResponse = @json.from_json(
        error,
        path=json_path.add_key("error"),
      )
      Some(error)
    }
    None => None
  }
  ChatCompletionChunk::{
    id,
    choices,
    created: created.to_int(),
    model,
    usage,
    system_fingerprint,
    service_tier,
    error,
  }
}

///|
/// Create an assistant message for chat completion.
///
/// Assistant messages represent responses from the AI model. They can contain
/// text content and/or tool call requests. This function is useful when
/// constructing multi-turn conversations or when replaying conversation history.
///
/// Parameters
/// - `content`: Optional content from the assistant
/// - `tool_calls`: Optional array of tool calls the assistant made
/// - `name`: Optional name to identify the assistant
///
/// Returns a ChatCompletionMessageParam with role "assistant".
pub fn[T : ToChatCompletionMessageParamContent] assistant_message(
  content? : T,
  tool_calls? : Array[ChatCompletionMessageToolCall] = [],
  name? : String,
) -> ChatCompletionMessageParam {
  let content = match content {
    Some(content) => content.to_chat_completion_message_param_content()
    None => []
  }
  ChatCompletionMessageParam::Assistant(ChatCompletionAssistantMessageParam::{
    content,
    name,
    tool_calls,
  })
}

///|
/// Create a JSON schema response format.
///
/// This function creates a response format that constrains the model to generate
/// JSON output conforming to a specific schema. The model will automatically
/// structure its response to match the provided schema.
///
/// Parameters
/// - `name`: A name for the schema (used for identification)
/// - `schema`: JSON schema object defining the expected structure
/// - `description`: Optional description of the schema's purpose
/// - `strict`: Optional flag to enable strict schema validation
///
/// Returns a ResponseFormat that can be used in chat completion requests.
pub fn json_schema(
  name~ : String,
  schema~ : Map[String, Json],
  description? : String,
  strict? : Bool,
) -> ResponseFormat {
  JsonSchema(JsonSchema::{ name, description, schema, strict })
}

///|
pub impl ToJson for ResponseFormat with to_json(self : ResponseFormat) -> Json {
  match self {
    Text => { "type": "text" }
    JsonSchema(json_schema) =>
      {
        "type": "json_schema",
        "json_schema": {
          let object : Map[String, Json] = {
            "name": Json::string(json_schema.name),
            "schema": json_schema.schema.to_json(),
          }
          if json_schema.description is Some(description) {
            object["description"] = Json::string(description)
          }
          if json_schema.strict is Some(strict) {
            object["strict"] = Json::boolean(strict)
          }
          Json::object(object)
        },
      }
    JsonObject => { "type": "json_object" }
  }
}

///|
pub fn tool_call(
  id~ : String,
  name~ : String,
  arguments~ : String,
) -> ChatCompletionMessageToolCall {
  ChatCompletionMessageToolCall::{
    id,
    function: ChatCompletionMessageToolCallFunction::{
      name,
      arguments: Some(arguments),
    },
  }
}

///|
pub fn chunk(
  id~ : String,
  choices~ : Array[ChatCompletionChunkChoice],
  created~ : Int,
  model~ : String,
  usage? : CompletionUsage,
  system_fingerprint? : String,
  service_tier? : ChatCompletionChunkServiceTier,
  error? : OpenRouterErrorResponse,
) -> ChatCompletionChunk {
  ChatCompletionChunk::{
    id,
    choices,
    created,
    model,
    usage,
    system_fingerprint,
    service_tier,
    error,
  }
}

///|
pub fn chunk_choice_delta_tool_call_function(
  arguments? : String,
  name? : String,
) -> ChatCompletionChunkChoiceDeltaToolCallFunction {
  ChatCompletionChunkChoiceDeltaToolCallFunction::{ arguments, name }
}

///|
pub fn chunk_choice_delta_tool_call(
  index~ : Int,
  id? : String,
  function~ : ChatCompletionChunkChoiceDeltaToolCallFunction,
) -> ChatCompletionChunkChoiceDeltaToolCall {
  ChatCompletionChunkChoiceDeltaToolCall::{ index, id, function }
}

///|
pub fn chunk_choice_delta(
  content? : String,
  refusal? : String,
  role? : ChatCompletionRole,
  tool_calls? : Array[ChatCompletionChunkChoiceDeltaToolCall],
) -> ChatCompletionChunkChoiceDelta {
  ChatCompletionChunkChoiceDelta::{ content, refusal, role, tool_calls }
}

///|
pub fn chunk_choice(
  index~ : Int,
  delta~ : ChatCompletionChunkChoiceDelta,
  finish_reason? : ChatCompletionChoiceFinishReason,
) -> ChatCompletionChunkChoice {
  ChatCompletionChunkChoice::{ index, delta, finish_reason }
}
