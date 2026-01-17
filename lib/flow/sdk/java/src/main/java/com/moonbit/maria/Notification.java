package com.moonbit.maria;

import com.google.gson.JsonElement;
import com.google.gson.annotations.SerializedName;

/**
 * Base class for all notification types from Maria.
 */
public abstract class Notification {
    @SerializedName("method")
    private String method;

    public String getMethod() {
        return method;
    }

    public void setMethod(String method) {
        this.method = method;
    }

    /**
     * Notification sent when a conversation starts.
     */
    public static class ConversationStart extends Notification {
        @SerializedName("params")
        private ConversationStartParams params;

        public ConversationStartParams getParams() {
            return params;
        }

        public void setParams(ConversationStartParams params) {
            this.params = params;
        }
    }

    /**
     * Parameters for ConversationStart notification.
     */
    public static class ConversationStartParams {
        // Empty params for now
    }

    /**
     * Notification sent when an AI request is completed.
     */
    public static class RequestCompleted extends Notification {
        @SerializedName("params")
        private RequestCompletedParams params;

        public RequestCompletedParams getParams() {
            return params;
        }

        public void setParams(RequestCompletedParams params) {
            this.params = params;
        }
    }

    /**
     * Parameters for RequestCompleted notification.
     */
    public static class RequestCompletedParams {
        @SerializedName("usage")
        private CompletionUsage usage;

        @SerializedName("message")
        private ChatCompletionMessage message;

        public CompletionUsage getUsage() {
            return usage;
        }

        public void setUsage(CompletionUsage usage) {
            this.usage = usage;
        }

        public ChatCompletionMessage getMessage() {
            return message;
        }

        public void setMessage(ChatCompletionMessage message) {
            this.message = message;
        }
    }

    /**
     * Notification sent when a tool is called.
     */
    public static class PostToolCall extends Notification {
        @SerializedName("params")
        private PostToolCallParams params;

        public PostToolCallParams getParams() {
            return params;
        }

        public void setParams(PostToolCallParams params) {
            this.params = params;
        }
    }

    /**
     * Parameters for PostToolCall notification.
     */
    public static class PostToolCallParams {
        @SerializedName("tool_call")
        private ChatCompletionMessageToolCall toolCall;

        @SerializedName("json")
        private JsonElement json;

        @SerializedName("text")
        private String text;

        public ChatCompletionMessageToolCall getToolCall() {
            return toolCall;
        }

        public void setToolCall(ChatCompletionMessageToolCall toolCall) {
            this.toolCall = toolCall;
        }

        public JsonElement getJson() {
            return json;
        }

        public void setJson(JsonElement json) {
            this.json = json;
        }

        public String getText() {
            return text;
        }

        public void setText(String text) {
            this.text = text;
        }
    }

    /**
     * Represents token usage statistics.
     */
    public static class CompletionUsage {
        @SerializedName("completion_tokens")
        private int completionTokens;

        @SerializedName("prompt_tokens")
        private int promptTokens;

        @SerializedName("total_tokens")
        private int totalTokens;

        public int getCompletionTokens() {
            return completionTokens;
        }

        public void setCompletionTokens(int completionTokens) {
            this.completionTokens = completionTokens;
        }

        public int getPromptTokens() {
            return promptTokens;
        }

        public void setPromptTokens(int promptTokens) {
            this.promptTokens = promptTokens;
        }

        public int getTotalTokens() {
            return totalTokens;
        }

        public void setTotalTokens(int totalTokens) {
            this.totalTokens = totalTokens;
        }
    }

    /**
     * Represents a chat completion message.
     */
    public static class ChatCompletionMessage {
        @SerializedName("role")
        private String role;

        @SerializedName("content")
        private String content;

        @SerializedName("tool_calls")
        private ChatCompletionMessageToolCall[] toolCalls;

        public String getRole() {
            return role;
        }

        public void setRole(String role) {
            this.role = role;
        }

        public String getContent() {
            return content;
        }

        public void setContent(String content) {
            this.content = content;
        }

        public ChatCompletionMessageToolCall[] getToolCalls() {
            return toolCalls;
        }

        public void setToolCalls(ChatCompletionMessageToolCall[] toolCalls) {
            this.toolCalls = toolCalls;
        }
    }

    /**
     * Represents a tool call in a chat completion.
     */
    public static class ChatCompletionMessageToolCall {
        @SerializedName("id")
        private String id;

        @SerializedName("type")
        private String type;

        @SerializedName("function")
        private FunctionCall function;

        public String getId() {
            return id;
        }

        public void setId(String id) {
            this.id = id;
        }

        public String getType() {
            return type;
        }

        public void setType(String type) {
            this.type = type;
        }

        public FunctionCall getFunction() {
            return function;
        }

        public void setFunction(FunctionCall function) {
            this.function = function;
        }
    }

    /**
     * Represents a function call with name and arguments.
     */
    public static class FunctionCall {
        @SerializedName("name")
        private String name;

        @SerializedName("arguments")
        private String arguments;

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
        }

        public String getArguments() {
            return arguments;
        }

        public void setArguments(String arguments) {
            this.arguments = arguments;
        }
    }
}
