///|
let submit_schema : @tool.JsonSchema = @tool.JsonSchema::from_json({
  "properties": {
    "segment": {
      "description": "The fixed MoonBit code segment",
      "type": "string",
    },
  },
  "required": ["segment"],
  "type": "object",
})

///|
fn submit_moonbit_segment_new(task : Task) -> @tool.Tool[String] {
  @tool.new(
    name="submit_moonbit_segment",
    description="Submit a fixed MoonBit code segment for verification",
    schema=submit_schema,
    @tool.ToolFn(async fn(args) -> @tool.ToolResult[String] noraise {
      let { moon, segment, result } = task
      guard args is { "segment": patched, .. } else {
        return @tool.error("Missing 'segment' argument")
      }
      let patched : String = @json.from_json(patched) catch {
        error =>
          return @tool.error("Invalid 'segment' argument: \{error}", error~)
      }
      let diagnostics = moon.check_patch_replace(segment, patched) catch {
        error => return @tool.error("Failed to check patch: \{error}", error~)
      }
      guard diagnostics is Diagnostics([diagnostic, ..]) else {
        result.val = Some(patched)
        @tool.ok(
          "The submitted code segment has been verified to compile without errors.",
        )
      }
      let overlay = {}
      overlay[diagnostic.loc.path] = patched
      let rendered_diagnostics = diagnostics.render(
        context=1,
        limit=10,
        overlay~,
      )
      @tool.ok(
        "The submitted code segment has the following issues:\n\n" +
        "\{rendered_diagnostics}\n\n" +
        "Please fix these issues and resubmit the corrected code segment.",
      )
    }),
  )
}

///|
priv struct Task {
  moon : @moon.Module
  segment : @moon.SegmentView
  result : Ref[String?]
}

///|
async fn process_segment(
  model~ : @model.Model,
  cwd~ : String,
  moon~ : @moon.Module,
  segment~ : @moon.SegmentView,
  description~ : String,
  logger~ : @pino.Logger,
) -> String? {
  let result = Ref::new(None)
  let subagent = @agent.new(model, cwd~, logger~)
  subagent.add_tool(submit_moonbit_segment_new(Task::{ moon, segment, result }))
  subagent.add_message(
    @openai.system_message(
      content=(
        #|You are a highly skilled software developer with extensive knowledge in many programming languages, frameworks, design patterns, and best practices.
        #|In particular, you are an expert in the MoonBit programming language and you are primarily responsible for writing and improving MoonBit code.
        #|
        #|====
        #|
        #|CAPABILITIES
        #|
        #|- You can read and analyze MoonBit code and can write clean, efficient, and well-documented code.
        #|- You can debug complex issues and provide detailed explanations, offering architectural insights and design patterns.
        #|- You have access to the `submit_moonbit_segment` tool to submit and verify your fixed code segments.
        #|
        #|====
        #|
        #|RULES
        #|
        #|- Always read and understand the provided code segment before making changes.
        #|- When fixing code, ensure that your changes are minimal but effective, addressing all the reported issues.
        #|- Always use the `submit_moonbit_segment` tool to verify that your fix compiles without errors.
        #|- Provide complete, valid MoonBit code in your submissions - do not use placeholders or incomplete code.
        #|- Focus on fixing the specific issues mentioned in the diagnostics while maintaining code quality and best practices.
        #|- If the first attempt fails, analyze the error messages and refine your approach.
        #|
        #|====
        #|
        #|WORKFLOW
        #|
        #|1. Analyze the provided MoonBit code segment and understand the reported issues.
        #|2. Identify the root cause of each diagnostic/warning/error.
        #|3. Create a fixed version of the code segment that addresses all issues.
        #|4. Use the `submit_moonbit_segment` tool to verify your solution compiles correctly.
        #|5. If verification fails, analyze the error output and refine your fix until successful.
        #|
        #|Your goal is to provide a corrected MoonBit code segment that compiles without errors and addresses all the reported issues.
      ),
    ),
  )
  let user_message = StringBuilder::new()
  user_message.write_string(
    (
      $|Please fix the following MoonBit snippet with the following problem(s):
      $|
      $|**Problem Description:**
      $|
      $|\{description}
      $|
      $|**Original Segment:**
      $|
      $|```moonbit
      $|\{segment.content()}
      $|```
      $|
    ),
  )
  if segment.diagnostics().length() != 0 {
    user_message.write_string(
      (
        $|**Errors:**
        $|\{segment.diagnostics().render(context=1, limit=10)}
        $|
      ),
    )
  }
  user_message.write_string(
    (
      #|Please provide a corrected version of this snippet addressing all concerns above.
      #|Use the <submit_moonbit_segment/> tool to submit and verify your solution.
    ),
  )
  subagent.add_message(@openai.user_message(content=user_message.to_string()))
  subagent.start()
  result.val
}

///|
let schema : @tool.JsonSchema = @tool.JsonSchema::from_json({
  "type": "object",
  "properties": {
    "description": {
      "description": "A description of the changes to be made to fix the warnings/errors.",
      "type": "string",
    },
    "project_path": {
      "description": "The path to the project directory containing the moon.mod.json file.",
      "type": "string",
    },
  },
  "required": ["description", "project_path"],
})

///|
pub fn new(agent : @agent.Agent) -> @tool.Tool[String] {
  @tool.new(
    name="fix_moonbit_warnings",
    description="Fix all MoonBit warnings/errors in the given project directory by applying a batch suggestion to all relevant MoonBit top-level constructs.",
    schema~,
    @tool.ToolFn(async fn(args : Json) -> @tool.ToolResult[String] noraise {
      guard args
        is {
          "description": String(description),
          "project_path": String(project_path),
          ..
        } else {
        return @tool.error("Missing 'description' or 'project_path' argument")
      }
      let cwd = agent.cwd
      let project_path : String = if @path.is_absolute(project_path) {
        project_path
      } else {
        @path.join(cwd, project_path)
      }
      let moon = @moon.Module::load(project_path) catch {
        error => return @tool.error("Failed to load module: \{error}", error~)
      }
      let files = moon.files().collect()
      @async.with_timeout(
        120_000 * 4,
        () => moon.check(),
        error=Failure("Timeout after 4 minutes"),
      ) catch {
        error => return @tool.error("Failed to check module: \{error}", error~)
      }
      let mut files_updated = 0
      let mut segments_updated = 0
      let semaphore = @semaphore.Semaphore::new(4)
      @async.with_timeout(60_000 * 10 * 8, () => @async.with_task_group(group => {
        for file in files {
          if file.path().has_suffix(".mbt.md") {
            // Currently it is not supported to fix MoonBit code embedded in
            // markdown files
            continue
          }
          for segment in file.segments() {
            if segment.diagnostics().is_empty() {
              continue
            }
            semaphore.acquire()
            group.spawn_bg(() => {
              defer semaphore.release()
              let updated_opt = @async.with_timeout_opt(120_000 * 4, () => process_segment(
                model=agent.model,
                cwd=agent.cwd,
                moon~,
                segment~,
                description~,
                logger=agent.logger.child({
                  "tool": {
                    "name": "fix_moonbit_warnings",
                    "id": agent.uuid.v4().to_json(),
                  },
                }),
              ))
              if updated_opt is Some(Some(updated)) {
                segment.replace(updated)
                segments_updated += 1
              }
            })
          }
          files_updated += 1
        }
        @tool.ok(
          "Processed \{files_updated} files and updated \{segments_updated} segments.",
        )
      })) catch {
        error => @tool.error("Failed to process segments: \{error}")
      }
    }),
  )
}
