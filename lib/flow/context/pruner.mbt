///|
struct Pruner {
  logger : @pino.Logger
  token_counter : @token_counter.Counter
  safe_zone_tokens : Int
}

///|
pub fn Pruner::new(
  safe_zone_tokens~ : Int,
  logger~ : @pino.Logger,
) -> Pruner raise {
  Pruner::{
    logger,
    token_counter: @token_counter.Counter::new(logger~),
    safe_zone_tokens,
  }
}

///|
const ClearedToolOutputPlaceholder : String = "[Cleared: tool output. If you want to see the output, you can use the tool again.]"

///|
/// Prunes in-memory chat context until it fits within the configured safe-zone token budget.
///
/// The pruner only redacts tool response messages because they typically contain the
/// largest payloads and can be regenerated on demand. Tool messages are replaced with a
/// short placeholder while preserving the original tool call id so that downstream state
/// remains consistent.
///
/// Parameters:
///
/// * `pruner`: Maintains logging and token counting utilities.
/// * `messages`: Mutable conversation history that will be truncated in place.
/// * `tools`: Tool descriptors needed when estimating token counts.
///
/// The function recalculates the token usage after each redaction, logging the reduction,
/// and stops once the budget is respected or no more tool messages are available.
pub async fn Pruner::prune_messages(
  pruner : Pruner,
  messages : Array[@openai.ChatCompletionMessageParam],
  tools? : Array[@openai.ChatCompletionToolParam] = [],
) -> Unit {
  let tokens = pruner.token_counter.count_param(
    @openai.chat_completion(messages~, model="gpt-4o", tools~),
  )
  if tokens <= pruner.safe_zone_tokens {
    return
  }
  let mut pruned_tokens = tokens // current state
  let pruned_index = []
  let prune_goal_met = for i, message in messages {
    match message {
      Tool(tool) => {
        if tool.content is [Text({ text: ClearedToolOutputPlaceholder, .. })] {
          // Already cleared, skip
          continue
        }
        messages[i] = @openai.tool_message(
          content=ClearedToolOutputPlaceholder,
          tool_call_id=tool.tool_call_id,
        )
        pruned_index.push(i)
        // TODO: this is O(n^2), optimize by tracking deltas
        pruned_tokens = pruner.token_counter.count_param(
          @openai.chat_completion(messages~, model="gpt-4o", tools~),
        )
        if pruned_tokens <= pruner.safe_zone_tokens {
          break true
        }
      }
      _ => ()
    }
  } else {
    false
  }
  pruner.logger.info("ContextPruned", {
    "origin_token_count": tokens.to_json(),
    "pruned_token_count": pruned_tokens.to_json(),
    "pruned_index": pruned_index.to_json(),
    "pruned_goal_met": prune_goal_met.to_json(),
  })
}
