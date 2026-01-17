///|
priv struct Params {
  job_id : Int
  timeout : Int
  max_output_lines : Int
} derive(@json.FromJson)

///|
fn truncate_output(output : String, max_output_lines~ : Int) -> String {
  let lines = output.split("\n").collect()
  if lines.length() <= max_output_lines {
    output
  } else {
    let truncated_lines = lines[0:max_output_lines]
    let truncated_output = truncated_lines.join("\n")
    truncated_output
  }
}

///|
let schema : @tool.JsonSchema = @tool.JsonSchema::from_json({
  "type": "object",
  "properties": {
    "job_id": {
      "type": "number",
      "description": "The ID of the background job to wait for.",
    },
    "timeout": {
      "type": "number",
      "description": "The maximum time in milliseconds to wait for the job to complete. If the job does not complete within this time, an error is returned.",
    },
    "max_output_lines": {
      "type": "number",
      "description": "The maximum number of output lines to return directly. If the output exceeds this number, it will be truncated.",
    },
  },
  "required": ["job_id", "timeout", "max_output_lines"],
})

///|
pub fn new(manager : @job.Manager) -> @tool.Tool[String] {
  @tool.new(
    description="Wait for a background job to complete and capture its output.",
    name="wait_job",
    schema~,
    @tool.ToolFn(async fn(args) -> @tool.ToolResult[String] noraise {
      let params : Params = @json.from_json(args) catch {
        error => return @tool.error("Invalid parameters: \{error}")
      }
      let { job_id, timeout, max_output_lines } = params
      guard manager.get(@job.Id(job_id)) is Some(job) else {
        return @tool.error("Job with ID \{job_id} does not exist")
      }
      let status = @async.with_timeout_opt(timeout, () => job.wait()) catch {
        error =>
          return @tool.error("Failed to wait for job \{job_id}: \{error}")
      }
      guard status is Some(status) else {
        return @tool.error("Timeout waiting for job \{job_id} to complete")
      }
      let output = StringBuilder::new()
      output.write_string("Job \{job_id} completed with exit code \{status}\n")
      let stdout = @fsx.read_file(job.stdout) catch {
        error =>
          return @tool.error(
            "Failed to read stdout of job \{job_id} from \{job.stdout}: \{error}",
          )
      }
      output.write_string(
        "Stdout (\{job.stdout}):\n\{truncate_output(stdout, max_output_lines~)}\n",
      )
      let stderr = @fsx.read_file(job.stderr) catch {
        error =>
          return @tool.error(
            "Failed to read stderr of job \{job_id} from \{job.stderr}: \{error}",
          )
      }
      output.write_string(
        "Stderr:\n\{truncate_output(stderr, max_output_lines~)}\n",
      )
      @tool.ok(output.to_string())
    }),
  )
}
