///|
fn submit_fixed_file_new(ctx : FixingContext) -> @tool.Tool[String] {
  @tool.new(
    name="submit_fixed_file",
    description="Submit the complete fixed file content for verification",
    schema=submit_schema,
    async fn(args) -> @tool.ToolResult[String] noraise {
      let { content } : InputSubmit = @json.from_json(args) catch {
        err =>
          return @tool.error(
            "Invalid arguments provided to submit_fixed_file: \{err}",
          )
      }
      try {
        // Write the fixed content to file
        let diagnostics = @moon.check_syntax_of_string(path=ctx.path, content)
        if diagnostics.is_empty() {
          ctx.content = content
          @tool.ok(
            "File verification successful! The code compiles without syntax errors.",
          )
        } else {
          let syntax_errors = diagnostics.render(
            context=2,
            limit=DiagnosticLimit,
            overlay=Map::from_array([
              (@path.basename(ctx.path).to_string(), content),
            ]),
          )
          @tool.error(
            "File verification failed with syntax errors:\n\{syntax_errors}",
          )
        }
      } catch {
        error => @tool.error("Failed to write or verify file: \{error}", error~)
      }
    },
  )
}

///|
/// Fix syntax errors using a sub-agent
async fn fix_syntax_errors(ctx : FixingContext) -> Unit {
  // Create sub-agent
  let subagent = @agent.new(
    ctx.parent_agent.model,
    logger=ctx.parent_agent.logger.child({
      "tool": {
        "name": "meta_write_to_file",
        "id": ctx.parent_agent.uuid.v4().to_json(),
      },
    }),
    cwd=ctx.cwd,
  )

  // Add tools using factory functions
  subagent.add_tools([
    submit_fixed_file_new(ctx).to_agent_tool(),
    attempt_completion_new(ctx).to_agent_tool(),
  ])

  // Add system message
  subagent.add_message(
    @openai.system_message(content=syntax_error_expert_prompt),
  )

  // Add user message
  let user_message = build_fixing_user_message(
    ctx.description,
    ctx.content,
    ctx.syntax_errors,
  )
  subagent.add_message(@openai.user_message(content=user_message))

  // Start the sub-agent with a timeout (5 minutes)
  @async.with_timeout(300_000, () => subagent.start())
}

///|
/// Create a user message for the syntax fixing sub-agent
fn build_fixing_user_message(
  description : String,
  file_content : String,
  syntax_errors : String,
) -> String {
  (
    $|You are a MoonBit syntax fixing assistant. A file has been written but contains syntax errors that need to be fixed.\n\n
    $|**Task Description:**
    $|
    $|\{description}
    $|
    $|**File Content:**
    $|
    $|```moonbit
    $|\{file_content}
    $|```
    $|
    $|**Current Syntax Errors:**
    $|
    $|\{syntax_errors}
    $|
    $|**Your Task:**
    $|
    $|1. ONLY FIX SYNTAX ERRORS - DO NOT CHANGE THE BEHAVIOR
    $|2. Analyze the syntax errors and understand what needs to be fixed
    $|   All syntax errors are already reported, don't try to fix syntax errors not reported,
    $|   it may be your hallucination if you think there are more syntax errors.
    $|3. Use `submit_fixed_file` to provide the complete fixed file content    
    $|4. Continue until all syntax errors are fixed
    $|5. Call `attempt_completion` when done
    $|
    $|**Guidelines:**
    $|
    $|- Focus only on fixing syntax errors, not improving code quality
    $|- Preserve the original intent and functionality of the code, as much as possible
    $|- Use proper MoonBit syntax and conventions
    $|- If you cannot fix an error, explain why clearly
    $|- When syntax check passes, call `attempt_completion` immediately
  )
}
