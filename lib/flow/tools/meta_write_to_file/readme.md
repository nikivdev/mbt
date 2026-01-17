# meta_write_to_file Tool

## Overview

`meta_write_to_file` is an enhanced file writing tool that provides automatic formatting and syntax error correction for MoonBit files. It wraps the standard file writing operation with intelligent post-processing capabilities.

## Architecture

The tool is organized into several modules for clarity and maintainability:

### Module Structure

```
tools/meta_write_to_file/
├── tool.mbt          # Main tool implementation and orchestration
├── types.mbt         # Core data structures
├── types_json.mbt    # JSON parsing and Show implementations
├── utils.mbt         # Utility functions (diff generation)
└── tool_test.mbt     # Integration tests
```

### Key Components

#### 1. **types.mbt** - Data Structures
- `MetaWriteParams`: Input parameters (path, search, replace, description)
- `MetaWriteToFileResult`: Output result (path, message, diff, learning_prompt)
- `FixingContext`: Context passed to syntax-fixing sub-agent
- `DiffResult`: Result of diff comparison

#### 2. **types_json.mbt** - Serialization & Parsing
- `Show` implementation for `MetaWriteToFileResult`
- `parse_meta_write_params()`: Validates and extracts parameters from JSON

#### 3. **utils.mbt** - Utility Functions
- `generate_diff()`: Creates line-by-line diffs between old and new content
- Note: Currently uses a naive implementation; could be improved with git diff

#### 4. **tool.mbt** - Core Logic
Contains the main workflow orchestration:
- File writing (full replace or search/replace)
- MoonBit-specific processing
- Sub-agent spawning for syntax error fixing
- Result formatting with diffs

## How It Works

### Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. Parse & Validate Parameters                             │
│     - path (required)                                        │
│     - description (required)                                 │
│     - search (optional) / replace (optional)                │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Initial File Write                                       │
│     - If search provided: search & replace                   │
│     - Otherwise: full file replacement                       │
│     - Capture initial_content after write                    │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  3. MoonBit-Specific Processing (if .mbt/.mbt.md)           │
│     ┌─────────────────────────────────────────────┐        │
│     │ 3a. Format with `moon fmt`                  │        │
│     └─────────────────┬───────────────────────────┘        │
│                       │                                      │
│     ┌─────────────────▼───────────────────────────┐        │
│     │ 3b. Check for syntax errors                 │        │
│     │     using `moon check`                      │        │
│     └─────────────────┬───────────────────────────┘        │
│                       │                                      │
│                 ┌─────▼─────┐                               │
│                 │  Errors?  │                               │
│                 └─────┬─────┘                               │
│                  Yes  │  No                                 │
│         ┌─────────────┴──────────────┐                      │
│         ▼                             ▼                      │
│  ┌──────────────────┐         ┌──────────────┐             │
│  │ 3c. Spawn        │         │ 3d. Skip     │             │
│  │ Sub-Agent to Fix │         │ fixing       │             │
│  └──────────────────┘         └──────────────┘             │
│         │                             │                      │
│         └─────────────┬───────────────┘                      │
│                       │                                      │
│     ┌─────────────────▼───────────────────────────┐        │
│     │ 3e. Re-format after fixing                  │        │
│     └─────────────────────────────────────────────┘        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Generate Diff & Result                                   │
│     - Compare initial_content with final_content             │
│     - Generate diff if changes detected                      │
│     - Add learning prompt if syntax errors were fixed        │
└─────────────────────────────────────────────────────────────┘
```

### Sub-Agent for Syntax Fixing

When syntax errors are detected, the tool spawns a **sub-agent** with specialized tools:

1. **read_file**: Allows sub-agent to read current file content
2. **submit_fixed_file**: Submits corrected content and verifies compilation
3. **attempt_completion**: Signals completion (success or failure)

The sub-agent operates with:
- A focused system prompt emphasizing syntax error correction
- A 5-minute timeout to prevent infinite loops
- Iterative refinement: can read, fix, and verify multiple times

## Key Features

### 1. Automatic Formatting
- Runs `moon fmt` on all `.mbt` and `.mbt.md` files
- Silently ignores formatting errors

### 2. Syntax Error Detection
- Uses `moon check` to detect syntax errors (error codes 3000-3999)
- Filters for Error-level diagnostics only
- Skips syntax fixing for `.mbt.md` files (markdown with embedded code)

### 3. Intelligent Sub-Agent Fixing
- Spawns a separate agent with the parent's model
- Provides clear context: file path, description, syntax errors
- Iterative fixing with verification
- Returns to parent with fixed code or error report

### 4. Diff Generation
- Compares initial write with final result
- Shows what formatting/fixing changed
- Helps users understand automatic modifications

### 5. Learning Prompts
- When syntax errors are fixed, generates a learning prompt
- Encourages the parent agent to learn from corrections
- Includes original errors and fixed code diff

## Usage Example

```moonbit
let agent = @agent.new(model, cwd="~/project")
let tool = @meta_write_to_file.new(agent)

// Write a new file
let result = tool.call({
  "path": "example.mbt",
  "description": "Create a simple Hello World program",
  "replace": "fn main {\n  println(\"Hello\")\n}"
})

// Search and replace
let result = tool.call({
  "path": "example.mbt", 
  "description": "Update the greeting message",
  "search": "println(\"Hello\")",
  "replace": "println(\"Hello, World!\")"
})
```

## Potential Improvements

### 1. **Diff Generation**
**Current**: Naive line-by-line comparison
**Improvement**: Use `git diff` or a proper diff algorithm (Myers, Patience, etc.)
- Better context around changes
- Proper handling of moved lines
- Standard unified diff format

**Implementation**:
```moonbit
async fn generate_diff_improved(
  old_content : String,
  new_content : String,
  title : String,
) -> DiffResult {
  // Write to temp files
  let old_file = write_temp_file(old_content)
  let new_file = write_temp_file(new_content)
  
  // Use git diff --no-index
  let output = @spawn.spawn(
    "git",
    ["diff", "--no-index", "--unified=3", old_file, new_file],
    capture_output=true
  )
  
  // Parse and format output
  format_git_diff(output, title)
}
```

### 2. **Syntax Error Filtering**
**Current**: Only checks error code ranges (3000-3999)
**Improvement**: Categorize error types more precisely
- Distinguish between syntax errors, type errors, and semantic errors
- Allow configuration of which error types to auto-fix
- Skip auto-fix for ambiguous errors that need human judgment

### 3. **Sub-Agent Efficiency**
**Current**: Spawns new agent for each file with errors
**Improvement**: Reuse sub-agent across multiple files
- Maintain a pool of syntax-fixing agents
- Share learning across fixes in same session
- Batch similar fixes together

**Alternative**: Consider inline fixing without sub-agent for simple cases
```moonbit
async fn try_simple_fixes(syntax_errors : String) -> String? {
  // Pattern matching for common errors:
  // - Missing semicolons
  // - Unmatched braces
  // - Common typos (fn vs fun, etc.)
  match classify_error(syntax_errors) {
    SimpleFixable(fix) => Some(apply_fix(fix))
    _ => None  // Delegate to sub-agent
  }
}
```

### 4. **Incremental Formatting**
**Current**: Formats entire file after every write
**Improvement**: Format only changed sections for large files
- Use `moon fmt` with line range options (if available)
- Reduce processing time for large files
- Preserve formatting in untouched sections

### 5. **Caching & Memoization**
**Current**: No caching
**Improvement**: Cache compilation results
- Hash file content → cache check results
- Skip re-checking unchanged files
- Especially useful during iterative development

### 6. **Better Error Recovery**
**Current**: Returns error if sub-agent fails
**Improvement**: Provide actionable guidance
- Include specific lines that need fixing
- Suggest common solutions for detected patterns
- Allow parent agent to retry with refined instructions

### 7. **Configurable Behavior**
**Current**: Hard-coded behavior (always format, always fix)
**Improvement**: Make behavior configurable
```moonbit
pub struct MetaWriteConfig {
  auto_format : Bool        // Default: true
  auto_fix_syntax : Bool    // Default: true
  max_fix_attempts : Int    // Default: 3
  timeout_ms : Int          // Default: 300000
  show_diff : Bool          // Default: true
}
```

### 8. **Progress Reporting**
**Current**: Silent processing
**Improvement**: Report progress for long operations
- Notify when formatting starts
- Show sub-agent thinking progress
- Indicate verification steps

### 9. **Parallel Processing**
**Current**: Sequential (format → check → fix → format)
**Improvement**: Parallelize independent operations
- Format and check could potentially overlap
- Multiple files could be processed concurrently

### 10. **Better Learning Integration**
**Current**: Returns learning prompt in result
**Improvement**: Integrate learning more deeply
- Automatically add to conversation history
- Track recurring error patterns
- Build a knowledge base of fixes

## Design Decisions

### Why Sub-Agent vs. Direct Fixing?

**Advantages of Sub-Agent Approach**:
1. **Isolation**: Fixing logic separate from main agent context
2. **Specialization**: Focused system prompt for syntax fixing
3. **Iterative**: Can read, attempt, verify, and retry
4. **Observability**: Clear separation of concerns in logs
5. **Reusability**: Same pattern works for other meta-tools

**Trade-offs**:
- More resource intensive (separate agent instance)
- Higher latency (agent initialization + tool calls)
- More complex debugging (nested agent interactions)

### Why Capture Initial Content?

Capturing content immediately after initial write allows:
1. Accurate diffs showing formatter/fixer changes
2. Transparency for users about automatic modifications
3. Learning opportunity for parent agent

### Why Skip .mbt.md Files?

`.mbt.md` files are markdown with embedded MoonBit code blocks. They:
- May have intentionally invalid code (for examples)
- Have mixed syntax (markdown + code)
- Don't need to compile independently

## Testing Strategy

Tests cover:
1. **No-op scenario**: Valid code that doesn't need fixing
2. **Syntax fixing**: Invalid code that gets auto-corrected
3. **Search/replace**: Partial file updates
4. **Sub-agent behavior**: Verification that fixes are applied correctly

See `tool_test.mbt` for detailed test cases.

## Dependencies

- `@agent`: For sub-agent spawning
- `@moon`: For module loading and checking
- `@spawn`: For running moon fmt
- `@fs`: For file operations
- `@path`: For path manipulation
- `@openai`: For message construction

## Limitations

1. **Moon-specific**: Only works with MoonBit files; other languages need different implementations
2. **Timeout**: 5-minute timeout may be insufficient for complex fixes
3. **No rollback**: If sub-agent makes things worse, no automatic rollback
4. **Single file**: Doesn't handle cross-file syntax dependencies
5. **Basic diff**: Current diff algorithm is simplistic

## Conclusion

`meta_write_to_file` demonstrates an interesting pattern: augmenting standard tools with AI-powered correction capabilities. The modular structure makes it maintainable, and the sub-agent approach provides a clean separation of concerns. With the suggested improvements, particularly around diff generation and error categorization, this tool could become even more powerful and efficient.
