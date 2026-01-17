import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;
import com.google.gson.JsonSyntaxException;
import com.moonbit.maria.Maria;
import com.moonbit.maria.Notification;

/**
 * Example showing how to use the Maria Java SDK.
 *
 * This program sends a prompt to Maria and prints the responses.
 */
public class Main {
    public static void main(String[] args) {
        // Create a Maria instance
        Maria maria = new Maria();

        // Create a Gson instance for pretty-printing JSON
        Gson gson = new GsonBuilder().setPrettyPrinting().create();

        // Send a prompt to Maria and process the responses
        System.out.println("Starting Maria...\n");

        for (Notification event : maria.start("Hello?")) {
            String method = event.getMethod();

            if ("maria.agent.request_completed".equals(method)) {
                // This is a completed response from Maria
                Notification.RequestCompleted completed = (Notification.RequestCompleted) event;
                String content = completed.getParams().getMessage().getContent();

                if (content != null) {
                    System.out.println(content);
                }
            } else if ("maria.agent.post_tool_call".equals(method)) {
                // This is Maria calling a tool
                Notification.PostToolCall toolCall = (Notification.PostToolCall) event;
                Notification.ChatCompletionMessageToolCall tool = toolCall.getParams().getToolCall();

                String toolName = tool.getFunction().getName();
                String toolArgs = tool.getFunction().getArguments();

                try {
                    // Try to parse and pretty-print the arguments
                    JsonObject argsObj = gson.fromJson(toolArgs, JsonObject.class);
                    System.out.println("% " + toolName + " " + gson.toJson(argsObj));
                } catch (JsonSyntaxException e) {
                    // If parsing fails, just print as-is
                    System.out.println("% " + toolName + " " + toolArgs);
                }

                // Print the tool output
                String text = toolCall.getParams().getText();
                for (String line : text.split("\n")) {
                    System.out.println("> " + line);
                }
            }
        }

        System.out.println("\nMaria finished.");
    }
}
