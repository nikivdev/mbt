# Contributing to Maria

Thank you for your interest in contributing to **Maria**! This guide will help you get started with the project.

## What is MoonBit?

[MoonBit](https://www.moonbitlang.com) is a modern programming language designed for cloud-native and WebAssembly applications. Maria is built entirely in MoonBit, leveraging its async capabilities through [moonbitlang/async](https://github.com/moonbitlang/async).

### Installing the MoonBit Toolchain

To contribute to Maria, you'll need to install the MoonBit toolchain:

1. Visit the [MoonBit Home Page](https://www.moonbitlang.com) for installation instructions
2. Refer to the [MoonBit Documentation](https://docs.moonbitlang.com/en/latest/) for detailed usage guides

After installation, verify your setup:

```bash
moon version --all
```

### Using Maria

```bash
# Set up your API key
export OPENAI_API_KEY=<your_api_key>

# Update dependencies
moon update

# Run Maria
moon run . -- Hello
```

## Contributing Workflow

We follow the standard fork-and-pull request workflow:

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/maria.git
   cd maria
   git submodule update --init --recursive
   ```

3. **Create a feature branch**:
   ```bash
   git checkout -b my-feature-branch
   ```

4. **Make your changes** and commit them with clear, descriptive messages:
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

5. **Run checks locally** before pushing:
   ```bash
   moon check --deny-warn  # Check for errors and warnings
   moon fmt                # Format code
   moon test -v            # Run tests
   ```

6. **Push to your fork** and create a pull request:
   ```bash
   git push origin my-feature-branch
   ```

7. Open a pull request against the `main` branch of `moonbitlang/maria`

### CI Requirements

For CI checks to pass, you need to configure GitHub Action secrets in your forked repository:

- `OPENAI_API_KEY`: Required for OpenAI API integration tests
- `OPENROUTER_API_KEY`: Required for OpenRouter API integration tests

To add these secrets:
1. Go to your fork's **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add both `OPENAI_API_KEY` and `OPENROUTER_API_KEY` with your respective API keys

**Note:** Without these secrets, some CI tests will fail. If you don't have access to these APIs, mention it in your pull request and the maintainers can help run the tests.

### Git Configuration

Some tests require git to be configured:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## Tooling

### Mock Testing with `internal/mock`

Maria uses a sophisticated mock harness for testing that provides isolated, deterministic test environments. This is essential for testing asynchronous code that interacts with the filesystem and other side effects.

#### Key Features:
- **Isolated workspace**: Each test runs in a temporary package layout
- **Deterministic infrastructure**: Mock implementations for time, randomness, and UUIDs
- **Trajectory logging**: Captures logs under `__trajectories__/<test-name>`
- **Sensitive data filtering**: Automatically masks paths, environment variables, and secrets

#### Example Usage:

```moonbit
async test "writes file" (t : @test.Test) {
  @mock.run(t, async ctx => {
    let file = ctx.add_file("output.txt", content="hello")
    let text = file.read()
    @json.inspect(text, content="hello")
  })
}
```

#### Common Context Operations:
- `ctx.add_file(name, content=...)` - Create files in the workspace
- `ctx.add_directory(...)` - Create directories
- `ctx.json(value)` / `ctx.show(value)` - Emit data with automatic secret masking
- `ctx.logger` - Structured logging to trajectories
- `ctx.clock` - Deterministic mock clock
- `ctx.rand` - Deterministic random number generator

For more details, see the [internal/mock README](internal/mock/README.md).

### Visualizing Agent Trajectories with `jsonl2md`

The `jsonl2md` tool converts JSONL log files produced by tests into readable Markdown format, making it easier to inspect agent behavior and debug issues.

#### Usage:

```bash
moon run cmd/jsonl2md path/to/input.jsonl --output path/to/output.md
```

If `--output` is omitted, the output will be saved as `<input_stem>.md`.

#### What it Does:
- Parses JSONL files containing agent messages and tool calls
- Renders conversations in a structured Markdown format
- Formats tool call arguments (attempts JSON formatting, falls back to raw text)
- Numbers each message sequentially for easy reference

#### Example Output:

```markdown
# 1 User: Hello, how are you?

Hello, how are you?

# 2 Assistant: I am fine, thank you!

I am fine, thank you!
Here is more detail.

## Tool call argument: <get_weather>

<location>
  New York
</location>

# 3 ✓ Tool call result: <get_weather>

...
```

For more details and format specifications, see the [cmd/jsonl2md README](cmd/jsonl2md/README.md).

## Where to Start

Looking for a place to contribute? Here are some suggestions:

### Good First Issues

Check out issues tagged with:
- **`feature`**: New features that need implementation
- **`help-wanted`**: Issues that are ready for community contributions
- **`good-first-issue`**: Beginner-friendly issues

Browse the [issue tracker](https://github.com/moonbitlang/maria/issues) and look for these labels to find issues that match your interests and skill level.

### Areas to Contribute

- **Documentation**: Improve existing docs or add missing documentation
- **Testing**: Add tests for uncovered code paths
- **Bug fixes**: Fix reported bugs
- **Features**: Implement new features (discuss in an issue first for larger changes)
- **Performance**: Optimize existing code
- **Tooling**: Improve developer experience with better tools

### Before Starting Work

1. Check if someone else is already working on the issue (look for comments or linked PRs)
2. For significant changes, comment on the issue or open a new issue to discuss your approach
3. Keep your changes focused and incremental

## Code Style

- Follow the existing code style in the project
- Run `moon fmt` to format your code before committing
- Ensure `moon check --deny-warn` passes without warnings
- Write clear commit messages following conventional commit format (e.g., `feat:`, `fix:`, `docs:`)

## Testing

- Write tests for new features
- Ensure all existing tests pass: `moon test -v`
- Use the `@mock.run` harness for asynchronous tests
- Keep tests deterministic and isolated

## Getting Help

- **Documentation**: Check the [MoonBit Documentation](https://docs.moonbitlang.com/en/latest/)
- **Issues**: Ask questions in GitHub issues
- **Pull Requests**: Don't hesitate to ask for help in your PR if you're stuck

Thank you for contributing to Maria! 🚀
