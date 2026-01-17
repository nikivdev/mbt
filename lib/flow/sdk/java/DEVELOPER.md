# Maria Java SDK - Developer Notes

## Architecture Overview

The Java SDK follows the same pattern as the Python and Node.js SDKs:

1. **Executable Bundling**: The Maria native executable is bundled in the JAR's resources
2. **Process Management**: The SDK spawns the executable as a subprocess
3. **JSON-RPC Communication**: Communication happens via stdout using JSON-RPC format
4. **Event Streaming**: Events are streamed line-by-line and parsed as they arrive

## Project Structure

```plaintext
sdk/java/
├── src/main/java/com/moonbit/maria/
│   ├── Maria.java          # Main SDK class
│   └── Notification.java   # Event type definitions
├── src/main/resources/bin/
│   └── <platform>.exe      # Platform-specific executables
├── examples/
│   ├── Main.java          # Example usage
│   └── pom.xml            # Example project config
├── pom.xml                # Main project Maven config
└── README.md              # User documentation
```

## Key Components

### Maria.java

The main class that:

- Extracts the executable from JAR resources to a temp file
- Spawns the process with `exec` command and user prompt
- Provides an Iterator interface for consuming events
- Handles process lifecycle and cleanup

### Notification.java

Defines the event types:

- `RequestCompleted`: AI response messages
- `PostToolCall`: Tool execution events
- Associated data classes matching OpenAI's API structure

## Platform Detection

The SDK detects the platform using Java's system properties:

- `os.name` → maps to: darwin, linux, windows
- `os.arch` → maps to: arm64, x86_64

The executable filename format: `{os}-{arch}.exe`

## Building and Publishing

### Development Build

```bash
cd sdk/java
mvn clean package
```

### Including the Executable

Before building, bundle the executable:

```bash
# From repository root
python scripts/bundle_maria_java.py
```

This copies `target/native/release/build/sdk.exe` to the appropriate location in the Java SDK.

### Publishing to Maven Central

1. Configure Maven credentials in `~/.m2/settings.xml`
2. Update version in `pom.xml`
3. Build and deploy:

```bash
mvn clean deploy
```

## Dependencies

- **Gson 2.10.1**: For JSON parsing (similar to openai's json usage in other SDKs)
- **Java 17+**: For modern language features and better process handling

## Testing

Currently relies on manual testing via the examples. Future improvements:

- Add JUnit tests
- Mock the subprocess for unit testing
- Integration tests with a test executable

## Differences from Other SDKs

### vs Python SDK

- Python uses async/await; Java uses Iterator (blocking I/O)
- Python uses Pydantic; Java uses Gson with POJOs
- Python has `asyncio.create_subprocess_exec`; Java has `ProcessBuilder`

### vs Node.js SDK

- Node.js uses async generators; Java uses Iterator
- Node.js has built-in JSON parsing; Java uses Gson
- Similar subprocess spawning approach

## Common Issues

### "Executable not found"

The executable must be bundled before building. Run `bundle_maria_java.py` first.

### "Permission denied"

On Unix systems, the executable needs execute permissions. The SDK calls `setExecutable(true)` but this may fail in some environments.

### "Process exited with code X"

Check that:

1. The executable is the correct version for the platform
2. All required environment variables are set
3. Dependencies are available (if the executable needs shared libraries)

## Future Improvements

1. **Async Support**: Add CompletableFuture-based async API
2. **Better Error Handling**: Parse stderr for detailed error messages
3. **Streaming Callback API**: Alternative to Iterator for reactive programming
4. **Resource Management**: Use try-with-resources pattern
5. **Testing**: Comprehensive test suite
6. **Platform Variants**: Support more platform combinations

## Maintenance Checklist

When updating the SDK:

- [ ] Update version in `pom.xml`
- [ ] Test on all supported platforms (macOS, Linux, Windows)
- [ ] Update `README.md` with new features
- [ ] Update examples if API changes
- [ ] Run `mvn clean test package` to verify build
- [ ] Test with bundled executable
- [ ] Update CHANGELOG (if exists)

## Resources

- [Maven Central Publishing Guide](https://central.sonatype.org/publish/publish-guide/)
- [Gson User Guide](https://github.com/google/gson/blob/master/UserGuide.md)
- [Java Process API](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Process.html)
