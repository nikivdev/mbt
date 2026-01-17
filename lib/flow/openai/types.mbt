///|
/// Data models mirroring OpenAI chat-completion REST payloads.
/// Use `ChatCompletionParam` to build requests and expect `ChatCompletion`
/// to represent responses and streaming deltas.

///|
/// Service tier override for chat completion requests.
pub(all) enum ChatCompletionServiceTier {
  Auto
  Default
  Flex
  Scale
  Priority
} derive(Show)

///|
typealias ChatCompletionServiceTier as ChatCompletionChunkServiceTier

///|
/// Aggregated log-probability details for a streamed choice.
pub struct ChatCompletionChoiceLogprobs {
  content : Array[ChatCompletionTokenLogprob]?
  refusal : Array[ChatCompletionTokenLogprob]?
} derive(Show)

///|
/// Token logprob information
pub struct ChatCompletionTokenLogprob {
  token : String
  logprob : Double
  bytes : Array[Int]?
  top_logprobs : Array[ChatCompletionTopLogprob]
} derive(Show)

///|
/// Top logprob information
pub struct ChatCompletionTopLogprob {
  token : String
  logprob : Double
  bytes : Array[Int]?
} derive(Show)

///|
/// Tool function metadata returned from the API.
pub struct ChatCompletionMessageToolCallFunction {
  arguments : String?
  name : String
} derive(Show)

///|
/// Tool call emitted from an assistant message.
pub struct ChatCompletionMessageToolCall {
  id : String
  function : ChatCompletionMessageToolCallFunction
} derive(Show)

///|
/// Message author roles reflected in completion responses.
pub enum ChatCompletionMessageRole {
  Assistant
} derive(Show)

///|
/// Assistant message returned by chat completions.
pub struct ChatCompletionMessage {
  content : String?
  refusal : String?
  role : ChatCompletionMessageRole
  tool_calls : Array[ChatCompletionMessageToolCall]
} derive(Show, ToJson)

///|
/// Reason why the model stopped generating tokens.
pub enum ChatCompletionChoiceFinishReason {
  Stop
  Length
  ToolCalls
  ContentFilter
  FunctionCall
} derive(Show)

///|
/// Single choice returned in a chat completion response.
pub struct ChatCompletionChoice {
  finish_reason : ChatCompletionChoiceFinishReason?
  index : Int
  message : ChatCompletionMessage
  logprobs : ChatCompletionChoiceLogprobs?
} derive(Show)

///|
/// Token usage details for the model-completion segment.
pub struct CompletionTokensDetails {
  reasoning_tokens : Int?
} derive(Show, ToJson)

///|
/// Detailed billing information for a request.
pub struct CostDetails {
  upstream_inference_cost : Double?
} derive(Show, ToJson)

///|
/// Token usage details for the prompt segment.
pub struct PromptTokensDetails {
  cached_tokens : Int?
  audio_tokens : Int?
} derive(Show, ToJson)

///|
/// Aggregated usage information for a completion response.
pub struct CompletionUsage {
  completion_tokens : Int
  completion_tokens_details : CompletionTokensDetails?
  cost : Double?
  cost_details : CostDetails?
  prompt_tokens : Int
  prompt_tokens_details : PromptTokensDetails?
  total_tokens : Int
} derive(Show, ToJson)

///|
/// Controls whether the API returns usage statistics.
pub struct CompletionUsageParam {
  include_ : Bool
}

///|
pub struct ChatCompletionStreamOptionsParam {
  include_obfuscation : Bool?
  include_usage : Bool?
}

///|
/// Parameters accepted by the chat completion endpoint.
pub struct ChatCompletionParam {
  model : String
  messages : Array[ChatCompletionMessageParam]
  tools : Array[ChatCompletionToolParam]
  usage : CompletionUsageParam?
  user : String?
  max_tokens : Int?
  temperature : Double?
  response_format : ResponseFormat?
  stream : Bool?
  stream_options : ChatCompletionStreamOptionsParam?
  tool_choice : ChatCompletionToolChoice?
}

///|
pub(all) struct ChatCompletionFunctionToolChoice {
  name : String
}

///|
pub(all) struct ChatCompletionCustomToolChoice {
  name : String
}

///|
/// Constrains the tools available to the model to a pre-defined set.
///
/// `Auto` allows the model to pick from among the allowed tools and generate a message.
///
/// `Required` requires the model to call one or more of the allowed tools.
pub(all) enum ChatCompletionAllowedToolsMode {
  /// Allows the model to pick from among the allowed tools and generate a message.
  Auto
  /// Requires the model to call one or more of the allowed tools.
  Required
}

///|
/// Constrains the tools available to the model to a pre-defined set.
pub(all) struct ChatCompletionAllowedTools {
  /// Constrains the tools available to the model to a pre-defined set.
  ///
  /// `Auto` allows the model to pick from among the allowed tools and generate a message.
  ///
  /// `Required` requires the model to call one or more of the allowed tools.
  mode : ChatCompletionAllowedToolsMode
  // /A list of tool definitions that the model should be allowed to call.
  /// For the Chat Completions API, the list of tool definitions might look like:
  tools : Array[ChatCompletionToolChoice]
}

///|
/// Controls which (if any) tool is called by the model. `None` means the model
/// will not call any tool and instead generates a message. `Auto` means the
/// model can pick between generating a message or calling one or more tools.
/// `Required` means the model must call one or more tools. Specifying a
/// particular tool via `Function({ name: "my_function" })` forces the model to
/// call that tool.
///
/// `None` is the default when no tools are present. `Auto` is the default if
/// tools are present.
pub(all) enum ChatCompletionToolChoice {
  Disallow
  Auto
  Required
  AllowedTools(ChatCompletionAllowedTools)
  Function(ChatCompletionFunctionToolChoice)
  Custom(ChatCompletionCustomToolChoice)
}

///|
/// Chat completion response metadata.
pub struct ChatCompletion {
  id : String
  choices : Array[ChatCompletionChoice]
  created : Int
  model : String
  usage : CompletionUsage?
  system_fingerprint : String?
  service_tier : ChatCompletionServiceTier?
} derive(Show)

///|
/// Content parts supported in chat completion parameters.
pub enum ChatCompletionContentPartParam {
  Text(ChatCompletionContentPartTextParam)
}

///|
/// Cache directives for individual content parts.
pub(all) enum CacheControl {
  Ephemeral
}

///|
/// Plain text content to send with a chat message.
pub struct ChatCompletionContentPartTextParam {
  text : String
  cache_control : CacheControl?
}

///|
/// System message payload used to steer the assistant.
pub struct ChatCompletionSystemMessageParam {
  content : Array[ChatCompletionContentPartParam]
  name : String?
}

///|
/// User message payload sent to the model.
pub struct ChatCompletionUserMessageParam {
  content : Array[ChatCompletionContentPartParam]
  name : String?
}

///|
typealias ChatCompletionMessageToolCall as ChatCompletionMessageToolCallParam

///|
/// Assistant message payload in request parameters.
pub struct ChatCompletionAssistantMessageParam {
  content : Array[ChatCompletionContentPartParam]
  name : String?
  tool_calls : Array[ChatCompletionMessageToolCallParam]
}

///|
/// Tool message payload echoing tool outputs.
pub struct ChatCompletionToolMessageParam {
  content : Array[ChatCompletionContentPartParam]
  tool_call_id : String
}

///|
/// Messages supplied to the chat completion endpoint.
pub(all) enum ChatCompletionMessageParam {
  System(ChatCompletionSystemMessageParam)
  User(ChatCompletionUserMessageParam)
  Assistant(ChatCompletionAssistantMessageParam)
  Tool(ChatCompletionToolMessageParam)
}

///|
/// JSON schema describing a callable function.
pub struct FunctionDefinition {
  name : String
  description : String
  parameters : Json
  strict : Bool?
}

///|
/// Tool definitions accepted in chat completion requests.
pub enum ChatCompletionToolParam {
  Function(FunctionDefinition)
}

///|
/// Partial tool function payload emitted in streaming deltas.
pub struct ChatCompletionChunkChoiceDeltaToolCallFunction {
  arguments : String?
  name : String?
} derive(ToJson)

///|
/// Partial tool call emitted in streaming deltas.
pub struct ChatCompletionChunkChoiceDeltaToolCall {
  index : Int
  id : String?
  function : ChatCompletionChunkChoiceDeltaToolCallFunction
} derive(ToJson)

///|
/// Roles that may appear in streamed completion deltas.
pub enum ChatCompletionRole {
  Developer
  System
  User
  Assistant
  Tool
} derive(ToJson)

///|
/// Delta payload for a streamed chat completion chunk.
pub struct ChatCompletionChunkChoiceDelta {
  content : String?
  refusal : String?
  role : ChatCompletionRole?
  tool_calls : Array[ChatCompletionChunkChoiceDeltaToolCall]?
} derive(ToJson)

///|
/// Streaming choice wrapper returned by the API.
pub struct ChatCompletionChunkChoice {
  index : Int
  delta : ChatCompletionChunkChoiceDelta
  finish_reason : ChatCompletionChoiceFinishReason?
} derive(ToJson)

///|
/// Response format preferences for the assistant output.
pub(all) enum ResponseFormat {
  Text
  JsonSchema(JsonSchema)
  JsonObject
}

///|
/// Schema definition for JSON responses.
struct JsonSchema {
  name : String
  description : String?
  schema : Map[String, Json]
  strict : Bool?
}
