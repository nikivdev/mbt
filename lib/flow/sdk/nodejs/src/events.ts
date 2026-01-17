import type {
  ChatCompletionMessage,
  ChatCompletionMessageToolCall,
} from "openai/resources/chat/completions";
import type { CompletionUsage } from "openai/resources";

export interface RequestCompletedParams {
  usage: CompletionUsage;
  message: ChatCompletionMessage;
}

export interface RequestCompleted {
  method: "maria.agent.request_completed";
  params: RequestCompletedParams;
}

export interface PostToolCallParams {
  tool_call: ChatCompletionMessageToolCall;
  json: any;
  text: string;
}

export interface PostToolCall {
  method: "maria.agent.post_tool_call";
  params: PostToolCallParams;
}

export type Notification = RequestCompleted | PostToolCall;
