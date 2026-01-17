///|
pub struct CommandOutput {
  text : String
  truncated_lines : Int
  original_lines : Int
} derive(ToJson, @json.FromJson)

///|
pub enum CommandResult {
  Completed(
    command~ : String,
    status~ : Int,
    stdout~ : String,
    stderr~ : String,
    max_output_lines~ : Int
  )
  TimedOut(
    command~ : String,
    timeout~ : Int,
    stdout~ : String,
    stderr~ : String,
    max_output_lines~ : Int
  )
  Background(command~ : String, job_id~ : @job.Id)
} derive(@json.FromJson, ToJson)

///|
fn render_output(
  name~ : String,
  output : String,
  max_output_lines~ : Int,
) -> String {
  let formatted = StringBuilder::new()
  let lines = output.split("\n").collect()
  if lines.length() >= max_output_lines {
    formatted.write_string(
      "=== \{name} (first \{max_output_lines} of \{lines.length()} lines) ===\n",
    )
    formatted.write_string(lines[:max_output_lines].join("\n"))
    formatted.write_string(
      "\n... (truncated, try using redirection to pipe output to a file) ...",
    )
  } else {
    formatted.write_string("=== \{name} (\{lines.length()} lines) ===\n")
    formatted.write_string(output)
  }
  formatted.to_string()
}

///|
pub impl Show for CommandResult with output(
  self : CommandResult,
  logger : &Logger,
) -> Unit {
  match self {
    Completed(command~, status~, stdout~, stderr~, max_output_lines~) => {
      let formatted = []
      formatted.push("Command \{command} exited with status \{status}.")
      formatted.push(render_output(name="STDOUT", stdout, max_output_lines~))
      formatted.push(render_output(name="STDERR", stderr, max_output_lines~))
      logger.write_string(formatted.join("\n"))
    }
    TimedOut(command~, timeout~, stdout~, stderr~, max_output_lines~) => {
      let formatted = []
      formatted.push("Command \{command} timed out after \{timeout} seconds.")
      formatted.push(render_output(name="STDOUT", stdout, max_output_lines~))
      formatted.push(render_output(name="STDERR", stderr, max_output_lines~))
      logger.write_string(formatted.join("\n"))
    }
    Background(command~, job_id~) =>
      logger.write_string(
        "Command \{command} started in background with Job ID \{job_id}",
      )
  }
}

///|
pub fn new(ctx : @job.Manager) -> @tool.Tool[CommandResult] {
  @tool.new(
    description="Execute an shell command with arguments and capture its output.",
    name="execute_command",
    schema~,
    @tool.ToolFn(async fn(args) -> @tool.ToolResult[CommandResult] noraise {
      guard args is { "command": String(command), .. } else {
        return @tool.error("Error: 'command' parameters is required")
      }
      let timeout = if args is { "timeout": timeout, .. } {
        guard timeout.as_number() is Some(timeout) else {
          return @tool.error("'timeout' must be a number")
        }
        if timeout <= 0 {
          return @tool.error("'timeout' must be a positive integer")
        }
        timeout
      } else {
        600_000
      }
      let max_output_lines = if args
        is { "max_output_lines": Number(max_output_lines, ..), .. } {
        if max_output_lines <= 0 {
          return @tool.error("'max_output_lines' must be a positive integer")
        }
        max_output_lines.to_int()
      } else {
        100
      }
      let working_directory = if args
        is { "working_directory": String(working_directory), .. } {
        if @path.is_absolute(working_directory) {
          working_directory
        } else {
          @path.join(ctx.cwd, working_directory)
        }
      } else {
        ctx.cwd
      }
      let background = if args is { "background": background, .. } {
        guard background.as_bool() is Some(background) else {
          return @tool.error("'background' must be a boolean")
        }
        background
      } else {
        false
      }
      if background {
        let job = ctx.spawn(name=command, command~) catch {
          error =>
            return @tool.error(
              "Failed to start background job for command '\{command}': \{error}",
            )
        }
        @tool.ok(CommandResult::Background(command~, job_id=job.id))
      } else {
        let timeout = timeout.to_int()
        let process = @spawn.spawn(
          "sh",
          ["-c", command],
          timeout~,
          cwd=working_directory,
        ) catch {
          @spawn.TimedOut(timeout~, stdout~, stderr~) =>
            return @tool.ok(
              CommandResult::TimedOut(
                command~,
                timeout~,
                stdout~,
                stderr~,
                max_output_lines~,
              ),
            )
          error =>
            return @tool.error(
              "Failed to execute command '\{command}': \{error}",
              error~,
            )
        }
        return @tool.ok(
          CommandResult::Completed(
            command~,
            status=process.status,
            stdout=process.stdout,
            stderr=process.stderr,
            max_output_lines~,
          ),
        )
      }
    }),
  )
}
