///|
/// Represents an AI agent that interacts with language models and executes tools.
///
/// The `Agent` struct encapsulates the complete state and behavior of an AI agent,
/// including conversation history, available tools, model configuration, and event
/// handling. It manages the conversation loop, token counting, context pruning,
/// and tool execution.
///
/// Fields:
///
/// * `rand` : Random number generator for generating UUIDs and other random values.
/// * `uuid` : UUID generator for creating unique identifiers.
/// * `cwd` : Current working directory used as the base path for tool operations.
/// * `model` : The AI model configuration and endpoint for generating responses.
/// * `logger` : Logger instance for recording agent activities and events.
/// * `tools` : Map of available tools indexed by their names.
/// * `history` : Conversation history containing all messages exchanged.
/// * `queue` : Pending messages to be sent in the next API call.
/// * `event_target` : Event dispatcher for handling agent lifecycle events.
/// * `token_counter` : Counter for tracking token usage across API calls.
/// * `context_pruner` : Pruner for managing context size within token budgets.
/// * `session_manager` : Manager for persisting and loading conversation sessions.
pub struct Agent {
  rand : @random.Rand
  uuid : @uuid.Generator
  cwd : String
  model : @model.Model
  logger : @pino.Logger
  priv tools : Map[String, @tool.AgentTool]
  priv history : @conversation.Conversation
  priv mut queue : Array[@openai.ChatCompletionMessageParam]
  priv event_target : @event.EventTarget
  priv token_counter : @token_counter.Counter
  priv context_pruner : @context.Pruner
  priv session_manager : @conversation.Manager
}

///|
/// Error raised when the API response contains no choices.
///
/// This error occurs when the chat completion response from the OpenAI API
/// returns an empty choices array, which indicates an unexpected API response
/// format or a failure in the model to generate a response.
priv suberror EmptyChoices

///|
/// Adds a message to the agent's message queue for the next API call.
///
/// The message is queued and will be sent to the API in the next `call()` operation.
/// After adding the message, a `MessageAdded` event is emitted.
///
/// Parameters:
///
/// * `agent` : The agent instance to add the message to.
/// * `message` : The chat completion message to queue for sending.
pub async fn Agent::add_message(
  agent : Agent,
  message : @openai.ChatCompletionMessageParam,
) -> Unit {
  agent.queue.push(message)
  agent.emit(MessageAdded(message))
}

///|
/// Closes the agent and performs any necessary cleanup.
///
/// This function is currently a placeholder for future cleanup operations
/// such as closing connections, flushing logs, or releasing resources.
///
/// Parameters:
///
/// * `agent` : The agent instance to close (currently unused).
pub fn Agent::close(_ : Agent) -> Unit {

}

///|
/// Executes a tool call requested by the AI model and returns the result.
///
/// This function handles the complete tool execution lifecycle:
/// 1. Validates that the requested tool exists
/// 2. Emits a `PreToolCall` event for logging/monitoring
/// 3. Parses and validates the tool arguments
/// 4. Executes the tool with the provided arguments
/// 5. Emits a `PostToolCall` event with the result
/// 6. Returns the result formatted as a tool message
///
/// Parameters:
///
/// * `agent` : The agent instance containing the available tools.
/// * `tool_call` : The tool call request from the AI model, containing the tool
///   name, arguments, and call ID.
///
/// Returns a `@openai.ChatCompletionMessageParam` containing either:
/// * The tool's successful output
/// * An error message if the tool doesn't exist, arguments are invalid, or
///   execution fails
///
/// The returned message maintains the `tool_call_id` to correlate with the
/// original request.
async fn Agent::execute_tool(
  agent : Agent,
  tool_call : @openai.ChatCompletionMessageToolCall,
) -> @openai.ChatCompletionMessageParam {
  guard agent.tools.get(tool_call.function.name) is Some(tool) else {
    @openai.tool_message(
      content="Unknown tool: \{tool_call.function.name}",
      tool_call_id=tool_call.id,
    )
  }
  agent.emit(PreToolCall(tool_call))
  match tool_call.function.arguments {
    None =>
      return @openai.tool_message(
        content="No arguments provided for tool call. To call a tool with empty arguments, supply an empty JSON object: {}",
        tool_call_id=tool_call.id,
      )
    Some(arguments) =>
      if arguments.is_empty() {
        return @openai.tool_message(
          content="No arguments provided for tool call. To call a tool with empty arguments, supply an empty JSON object: {}",
          tool_call_id=tool_call.id,
        )
      } else {
        let arguments = @json.parse(arguments) catch {
          error =>
            return @openai.tool_message(
              content="Error parsing tool arguments: \{error}",
              tool_call_id=tool_call.id,
            )
        }
        let (result, rendered) = match tool.call(arguments) {
          Ok((json, text)) => (Ok(json), text)
          Error(error, text) => (Err(error), text)
        }
        agent.emit(PostToolCall(tool_call, result~, rendered~))
        @openai.tool_message(content=rendered, tool_call_id=tool_call.id)
      }
  }
}

///|
/// Adds multiple tools to the agent's available tools collection.
///
/// This is a convenience function for adding multiple `AgentTool` instances
/// at once. Each tool is added individually and triggers a `ToolAdded` event.
///
/// Parameters:
///
/// * `agent` : The agent instance to add the tools to.
/// * `tools` : An array of `AgentTool` instances to be registered with the agent.
pub async fn Agent::add_tools(
  agent : Agent,
  tools : Array[@tool.AgentTool],
) -> Unit {
  for tool in tools {
    agent.add_agent_tool(tool)
  }
}

///|
/// Adds a single agent tool to the agent's tools collection.
///
/// The tool is indexed by its name in the agent's tool map and a `ToolAdded`
/// event is emitted for logging and monitoring purposes.
///
/// Parameters:
///
/// * `agent` : The agent instance to add the tool to.
/// * `tool` : The agent tool to register.
async fn Agent::add_agent_tool(agent : Agent, tool : @tool.AgentTool) -> Unit {
  let desc = tool.desc()
  agent.tools[desc.name] = tool
  agent.emit(ToolAdded(desc))
}

///|
/// Adds a tool to the agent's available tools collection.
///
/// Parameters:
///
/// * `agent` : The agent instance to add the tool to.
/// * `tool` : The tool to be added, which will be indexed by its name for
///   future tool calls.
pub async fn[Output : ToJson + Show] Agent::add_tool(
  agent : Agent,
  tool : @tool.Tool[Output],
) -> Unit {
  agent.add_agent_tool(tool.to_agent_tool())
}

///|
/// Prepares messages for an API request by counting tokens, pruning if needed, and applying caching.
///
/// This function performs the following operations:
/// 1. Counts tokens before pruning to track context size
/// 2. Emits a `TokenCounted` event for monitoring
/// 3. Prunes messages if they exceed the safe zone token budget
/// 4. Counts tokens after pruning to verify we're within budget
/// 5. Emits a `ContextPruned` event with before/after counts
/// 6. Applies prompt caching to optimize API performance
///
/// Parameters:
///
/// * `agent` : The agent instance containing token counter and context pruner.
/// * `messages` : The message array to prepare (modified in place during pruning).
/// * `tools` : The tools array for the API call (used for token counting).
///
/// Returns the cached messages ready to be sent to the API.
async fn Agent::prepare_messages_for_request(
  agent : Agent,
  messages : Array[@openai.ChatCompletionMessageParam],
  tools~ : Array[@openai.ChatCompletionToolParam],
) -> Array[@openai.ChatCompletionMessageParam] {
  // Count tokens before pruning to track context size
  let origin_token_count = agent.token_counter.count_param(
    @openai.chat_completion(
      messages~,
      model=agent.model.model_name,
      tools~,
      usage=@openai.usage(include_=true),
    ),
  )
  // Emit event with original token count for monitoring
  agent.emit(TokenCounted(origin_token_count))
  // Prune messages if they exceed the safe zone token budget
  // This modifies the messages array in place
  agent.context_pruner.prune_messages(messages, tools~)
  // Count tokens after pruning to verify we're within budget
  let pruned_token_count = agent.token_counter.count_param(
    @openai.chat_completion(
      messages~,
      model=agent.model.model_name,
      tools~,
      usage=@openai.usage(include_=true),
    ),
  )
  // Emit event with before/after token counts (only logged if pruning occurred)
  agent.emit(ContextPruned(origin_token_count~, pruned_token_count~))
  // Apply prompt caching to messages to improve API performance
  @cache.cache_messages(messages)
}

///|
/// Starts the agent's conversation loop and executes tool calls until completion.
///
/// This function implements the main agent execution loop:
/// 1. Spawns the event target in the background to handle event processing
/// 2. Emits a `PreConversation` event to signal the start
/// 3. Repeatedly calls the AI model and executes any requested tool calls
/// 4. Continues until the model returns a response with no tool calls
/// 5. Emits a `PostConversation` event when complete
///
/// The conversation loop automatically handles:
/// * Sending queued messages to the API
/// * Processing tool call requests from the model
/// * Executing tools and returning results
/// * Managing conversation history
///
/// Parameters:
///
/// * `agent` : The agent instance to start.
///
/// The function runs within an async task group to manage concurrent operations.
pub async fn Agent::start(agent : Agent) -> Unit {
  @async.with_task_group(group => {
    // Start the event target in background to handle async event processing
    group.spawn_bg(() => agent.event_target.start(), no_wait=true)
    // Signal the start of conversation
    agent.emit(PreConversation)
    while true {
      // Build the tools array for this API call
      // Convert each registered tool into OpenAI's tool parameter format
      let tools = []
      for name, tool in agent.tools {
        let desc = tool.desc()
        tools.push(
          @openai.tool(
            name~,
            description=desc.description,
            parameters=desc.schema.to_json(),
          ),
        )
      }
      // Retrieve and clear the message queue
      // staged contains messages that need to be sent in this call
      let staged = agent.queue
      agent.queue = []
      // Build the complete message array for the API call
      // Start with conversation history, then append any queued messages
      let messages = [..agent.history.to_param(), ..staged]

      // Count tokens, prune if needed, and apply caching
      let cache_messages = agent.prepare_messages_for_request(messages, tools~)

      // Make the API request to get the model's response
      let response = @openai.chat(
        model=agent.model,
        logger=agent.logger,
        @openai.chat_completion(
          messages=cache_messages,
          model=agent.model.model_name,
          tools~,
        ),
      )
      // Extract the message from the response, raise error if no choices returned
      guard response is { choices: [{ message, .. }, ..], usage, .. } else {
        raise EmptyChoices
      }

      // Emit event with API usage statistics and the returned message
      agent.emit(RequestCompleted(usage~, message~))
      // Add all staged messages to permanent conversation history
      agent.history.add_messages(staged)

      // Add the model's response to conversation history
      agent.history.add_message(message.to_param())
      // Persist the updated conversation history to disk
      agent.session_manager.save(agent.history)
      // Check if the model returned any tool calls
      // If not, the conversation is complete
      if message.tool_calls is [] {
        break
      }
      // Execute each tool call and queue the results for the next iteration
      for call in message.tool_calls {
        agent.add_message(agent.execute_tool(call))
      }
    }
    // Signal the end of conversation
    agent.emit(PostConversation)
  })
}

///|
/// Creates a new agent instance with the specified AI model and working directory.
///
/// This function initializes a complete agent with all necessary components:
/// * Random number generator and UUID generator (or uses provided ones)
/// * Logger for recording agent activities (defaults to file logging)
/// * Conversation history manager
/// * Token counter for tracking API usage
/// * Context pruner for managing message history within token budgets
/// * Empty tool collection and message queue
/// * Event target for handling lifecycle events
///
/// Parameters:
///
/// * `model` : The AI model to use for generating responses and handling tool calls.
/// * `rand` : Optional random number generator. If not provided, uses ChaCha8.
/// * `uuid` : Optional UUID generator. If not provided, creates one using the random generator.
/// * `logger` : Optional logger instance. Defaults to file logger at `.moonagent/log.jsonl`.
/// * `cwd` : The current working directory that will be used as the base path for tool operations.
///
/// Returns a new `Agent` instance initialized with empty conversation history,
/// no tools, and a fresh event target for handling agent lifecycle events.
///
/// The agent's context pruner is configured with the model's `safe_zone_tokens`
/// setting to automatically manage conversation history size.
pub async fn new(
  model : @model.Model,
  rand? : @random.Rand,
  uuid? : @uuid.Generator,
  logger? : @pino.Logger = @pino.logger(
    "agent",
    try! @pino.transport("file:.moonagent/log.jsonl"),
  ),
  cwd~ : StringView,
) -> Agent {
  // FIXME:(upstream) function with error not allowed in optional expression
  let rand = match rand {
    Some(rand) => rand
    None => @rand.chacha8()
  }
  let uuid = match uuid {
    Some(uuid) => uuid
    None => @uuid.generator(rand)
  }
  let session_manager = @conversation.Manager::new(uuid~, cwd~)
  let agent = Agent::{
    logger,
    rand,
    uuid,
    history: session_manager.new_conversation(name="history"),
    cwd: cwd.to_string(),
    model,
    tools: {},
    queue: [],
    event_target: @event.EventTarget::new(),
    token_counter: @token_counter.Counter::new(logger~),
    context_pruner: @context.Pruner::new(
      safe_zone_tokens=model.safe_zone_tokens,
      logger~,
    ),
    session_manager,
  }
  agent
}

///|
/// Emits an event and logs it to the agent's logger.
///
/// This function serves as the central event dispatcher for the agent. It both
/// emits events through the event target (for registered listeners) and logs
/// them using the agent's logger for persistent recording.
///
/// Each event type is logged with appropriate structured data:
/// * `TokenCounted` - Logs the token count for the current request
/// * `ContextPruned` - Logs before/after token counts (only if pruning occurred)
/// * `PreToolCall` - Logs tool name and parsed arguments
/// * `PostToolCall` - Logs tool result or error with rendered text
/// * `PreConversation` - Logs conversation start
/// * `PostConversation` - Logs conversation end
/// * `MessageAdded` - Logs the added message
/// * `ToolAdded` - Logs tool descriptor (name, description, schema)
/// * `RequestCompleted` - Logs API usage and response message
///
/// Parameters:
///
/// * `agent` : The agent instance emitting the event.
/// * `event` : The event to emit and log.
pub async fn Agent::emit(agent : Agent, event : @event.Event) -> Unit {
  agent.event_target.emit(event)
  let json = event.to_json()
  guard json is Object({ "msg": String(msg), .. } as json) else {  }
  json.remove("msg")
  agent.logger.info(msg, json)
}

///|
/// Registers an event listener for the specified event type on the agent.
///
/// Parameters:
///
/// * `agent` : The agent to add the event listener to.
/// * `f` : The asynchronous callback function to execute when the event is
///   triggered. The function receives an `Event` containing relevant
///   event data.
pub fn Agent::add_listener(
  agent : Agent,
  f : async (@event.Event) -> Unit,
) -> Unit {
  agent.event_target.add_listener(f)
}
