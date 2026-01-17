package com.moonbit.maria;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Iterator;
import java.util.NoSuchElementException;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;

/**
 * Main class for interacting with the Maria agent.
 *
 * <p>
 * Example usage:
 * </p>
 *
 * <pre>
 * Maria maria = new Maria();
 * for (Notification event : maria.start("Hello, Maria!")) {
 *     // Process event
 * }
 * </pre>
 */
public class Maria implements Iterable<Notification> {

    private static final Gson gson = new GsonBuilder().create();
    private String prompt;

    /**
     * Creates a new Maria instance.
     */
    public Maria() {
    }

    /**
     * Starts the Maria agent with the given prompt.
     *
     * @param prompt The prompt to send to Maria
     * @return An iterable of notifications from Maria
     */
    public Iterable<Notification> start(String prompt) {
        this.prompt = prompt;
        return this;
    }

    @Override
    public Iterator<Notification> iterator() {
        try {
            return new NotificationIterator(prompt);
        } catch (IOException e) {
            throw new RuntimeException("Failed to start Maria process", e);
        }
    }

    /**
     * Gets the system identifier for the current platform.
     *
     * @return A string like "darwin-aarch64" or "linux-amd64"
     */
    private static String getSystem() {
        String os = System.getProperty("os.name").toLowerCase();
        String arch = System.getProperty("os.arch").toLowerCase();

        // Normalize OS name
        String osName;
        if (os.contains("mac") || os.contains("darwin")) {
            osName = "darwin";
        } else if (os.contains("linux")) {
            osName = "linux";
        } else if (os.contains("windows")) {
            osName = "windows";
        } else {
            osName = os;
        }

        // Normalize architecture name
        String archName;
        archName = switch (arch) {
            case "amd64", "x86_64" -> "x86_64";
            case "aarch64", "arm64" -> "arm64";
            default -> arch;
        };

        return osName + "-" + archName;
    }

    /**
     * Iterator that reads notifications from the Maria process.
     */
    private static class NotificationIterator implements Iterator<Notification> {

        private final Process process;
        private final BufferedReader reader;
        private String nextLine;
        private boolean finished;

        NotificationIterator(String prompt) throws IOException {
            // Extract the executable from resources
            String system = getSystem();
            String resourcePath = "/bin/" + system + ".exe";

            Path tempFile;
            try (InputStream resourceStream = Maria.class.getResourceAsStream(resourcePath)) {
                if (resourceStream == null) {
                    throw new IOException("Executable not found for system: " + system);
                } // Create a temporary file for the executable
                tempFile = Files.createTempFile("maria-", ".exe");
                tempFile.toFile().deleteOnExit();
                Files.copy(resourceStream, tempFile, StandardCopyOption.REPLACE_EXISTING);
            }

            // Make it executable on Unix-like systems
            File execFile = tempFile.toFile();
            execFile.setExecutable(true);

            // Start the process
            ProcessBuilder pb = new ProcessBuilder(
                    execFile.getAbsolutePath(),
                    "exec",
                    prompt);
            pb.redirectError(ProcessBuilder.Redirect.INHERIT);

            this.process = pb.start();
            this.reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            this.finished = false;

            // Read the first line
            advance();
        }

        private void advance() {
            try {
                nextLine = reader.readLine();
                if (nextLine == null) {
                    finished = true;
                    cleanup();
                }
            } catch (IOException e) {
                finished = true;
                cleanup();
                throw new RuntimeException("Failed to read from Maria process", e);
            }
        }

        private void cleanup() {
            try {
                reader.close();
                int exitCode = process.waitFor();
                if (exitCode != 0) {
                    System.err.println("Maria process exited with code: " + exitCode);
                }
            } catch (IOException | InterruptedException e) {
                // Best effort cleanup
            }
        }

        @Override
        public boolean hasNext() {
            return !finished && nextLine != null;
        }

        @Override
        public Notification next() {
            if (!hasNext()) {
                throw new NoSuchElementException("No more notifications");
            }

            try {
                // Parse the JSON to determine the notification type
                JsonObject obj = gson.fromJson(nextLine, JsonObject.class);
                String method = obj.get("method").getAsString();

                Notification notification;
                switch (method) {
                    case "maria.agent.request_completed" ->
                        notification = gson.fromJson(nextLine, Notification.RequestCompleted.class);
                    case "maria.agent.post_tool_call" ->
                        notification = gson.fromJson(nextLine, Notification.PostToolCall.class);
                    case "maria.agent.conversation_start" ->
                        notification = gson.fromJson(nextLine, Notification.ConversationStart.class);
                    default -> throw new RuntimeException("Unknown notification method: " + method);
                }

                // Advance to the next line
                advance();

                return notification;
            } catch (RuntimeException e) {
                finished = true;
                cleanup();
                throw new RuntimeException("Failed to parse notification: " + nextLine, e);
            }
        }
    }
}
