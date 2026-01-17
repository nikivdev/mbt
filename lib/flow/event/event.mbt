///|
/// Event type that occurs during agent conversation lifecycle.
///
/// A typical conversation lifecycle looks like this:
///
/// ```moonbit no-check
/// // add system and user messages
/// MessageAdded (system)
/// MessageAdded (user)
/// // calling agent.start()
/// PreConversation
/// while true {
///   // count tokens before request
///   TokenCounted
///   // prune context if necessary
///   ContextPruned
///   // receive assistant response
///   RequestCompleted
///   // executing tool call
///   PreToolCall
///   PostToolCall
///   MessageAdded (tool)
///   // continue to iterate if there are more messages
/// }
/// // conversation ended
/// PostConversation
/// ```
pub(all) enum Event {
  /// Event triggered before a conversation starts.
  PreConversation
  /// Event triggered after a conversation ends.
  PostConversation
  /// Event triggered when a new message is added to the conversation.
  ///
  /// **Note**: This event will be triggered for system/user/tool messages.
  /// This means it's very likely that you should do some filtering based on the
  /// message role. For example, If you are listening for both MessageAdded and
  /// PostToolCall events, you would probably receive duplicate contents, one in
  /// `MessageAdded` and another in `PostToolCall`, and you may want to ignore
  /// the `MessageAdded` event for tool messages.
  ///
  /// FIXME: emit this event for assistant messages as well.
  MessageAdded(@openai.ChatCompletionMessageParam)
  /// Event triggered when a tool is added to the agent. This message will only
  /// be triggered once per agent instance.
  ToolAdded(@tool.ToolDesc)
  /// Event triggered before a tool is called.
  PreToolCall(@openai.ChatCompletionMessageToolCall)
  /// Event triggered after a tool call is completed.
  ///
  /// If you are interested in the result of the tool call, then this is the
  /// event you might want to listen for. Note you should not listen for
  /// MessageAdded for tool messages as the structural representation of tool
  /// call result will be lost.
  ///
  /// The `result` field can be used to determine whether the tool call was
  /// successful or not. `rendered` field is the string representation of the
  /// tool call result, which can be used for both human and LLM consumption.
  PostToolCall(
    @openai.ChatCompletionMessageToolCall,
    result~ : Result[Json, Error],
    rendered~ : String
  )
  /// Event triggered when tokens are counted for a message or tool call.
  /// Tokens are counted in following scenarios:
  ///
  /// 1. Before a request is being sent, tokens are counted for all messages
  ///    in the conversation history to decide if to perform context pruning.
  /// 2. The context pruning algorithm may count token for multiple times to
  ///    determine when to stop.
  ///
  /// FIXME: Currently this event is triggered multiple times in a row.
  TokenCounted(Int)
  /// Event triggered when context pruning is performed.
  ///
  /// FIXME: Currently this event is triggered even if the context is with-in
  /// the limit and no pruning is performed.
  ContextPruned(origin_token_count~ : Int, pruned_token_count~ : Int)
  /// Event triggered when a chat completion request is completed.
  ///
  /// If you are interested in details in the assistant response, then this is
  /// the event you might want to listen for. Compared to `MessageAdded` event,
  /// this event contains more information like `usage` and `tool_calls`.
  RequestCompleted(
    usage~ : @openai.CompletionUsage?,
    message~ : @openai.ChatCompletionMessage
  )
}

///|
struct EventTarget {
  queue : @aqueue.Queue[Event]
  listeners : Array[async (Event) -> Unit]
}

///|
pub fn EventTarget::new() -> EventTarget {
  EventTarget::{ queue: @aqueue.Queue::new(), listeners: [] }
}

///|
pub async fn EventTarget::emit(self : EventTarget, event : Event) -> Unit {
  self.queue.put(event)
}

///|
pub fn EventTarget::add_listener(
  self : EventTarget,
  f : async (Event) -> Unit,
) -> Unit {
  self.listeners.push(f)
}

///|
pub async fn EventTarget::start(self : EventTarget) -> Unit {
  while true {
    let event = self.queue.get()
    for listener in self.listeners {
      listener(event)
    }
  }
}

///|
pub impl ToJson for Event with to_json(self : Event) -> Json {
  match self {
    TokenCounted(token_count) =>
      { "msg": "TokenCounted", "token_count": token_count.to_json() }
    ContextPruned(origin_token_count~, pruned_token_count~) =>
      {
        "msg": "ContextPruned",
        "origin_token_count": origin_token_count.to_json(),
        "pruned_token_count": pruned_token_count.to_json(),
      }
    PreToolCall(tool_call) =>
      match tool_call.function.arguments {
        None =>
          {
            "msg": "PreToolCall",
            "tool_call": tool_call.to_json(),
            "name": tool_call.function.name.to_json(),
          }
        Some(arguments) =>
          try @json.parse(arguments) catch {
            error =>
              {
                "msg": "PreToolCall",
                "tool_call": tool_call.to_json(),
                "name": tool_call.function.name.to_json(),
                "args": tool_call.function.arguments.to_json(),
                "error": error.to_json(),
              }
          } noraise {
            args =>
              {
                "msg": "PreToolCall",
                "tool_call": tool_call.to_json(),
                "name": tool_call.function.name.to_json(),
                "args": args,
              }
          }
      }
    PostToolCall(tool_call, result~, rendered~) =>
      match result {
        Ok(output) =>
          {
            "msg": "PostToolCall",
            "tool_call": tool_call.to_json(),
            "name": tool_call.function.name.to_json(),
            "result": output.to_json(),
            "text": rendered.to_json(),
          }
        Err(error) =>
          {
            "msg": "PostToolCall",
            "tool_call": tool_call.to_json(),
            "name": tool_call.function.name.to_json(),
            "error": error.to_json(),
            "text": rendered.to_json(),
          }
      }
    PreConversation => { "msg": "PreConversation" }
    PostConversation => { "msg": "PostConversation" }
    MessageAdded(message) =>
      { "msg": "MessageAdded", "message": message.to_json() }
    ToolAdded(tool_desc) =>
      {
        "msg": "ToolAdded",
        "tool": {
          "name": tool_desc.name,
          "description": tool_desc.description,
          "schema": tool_desc.schema.to_json(),
        },
      }
    RequestCompleted(usage~, message~) =>
      {
        "msg": "RequestCompleted",
        "usage": usage.to_json(),
        "message": message.to_json(),
      }
  }
}
