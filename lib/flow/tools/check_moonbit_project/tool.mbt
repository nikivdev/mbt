///|
priv struct CheckMoonbitProjectParams {
  diagnostic_limit : Int?
  patch_code : String?
  patch_file_name : String?
  project_path : String
} derive(@json.FromJson, ToJson)

///|
fn params(
  diagnostic_limit? : Int,
  patch_code? : String,
  patch_file_name? : String,
  project_path~ : String,
) -> CheckMoonbitProjectParams {
  { diagnostic_limit, patch_code, patch_file_name, project_path }
}

///|
pub fn input_json(
  diagnostic_limit? : Int,
  patch_code? : String,
  patch_file_name? : String,
  project_path~ : String,
) -> Json {
  params(diagnostic_limit?, patch_code?, patch_file_name?, project_path~).to_json()
}

///|
test "params ToJson" {
  @json.inspect(
    params(
      diagnostic_limit=5,
      patch_code="let x : Int = \"string\"",
      patch_file_name="example.mbt",
      project_path=".",
    ),
    content={
      "diagnostic_limit": 5,
      "patch_code": "let x : Int = \"string\"",
      "patch_file_name": "example.mbt",
      "project_path": ".",
    },
  )
}

///|
pub struct CheckMoonbitProjectResult {
  diagnostics : @diagnostics.Diagnostics
  diagnostic_limit : Int
  rendered_diagnostics : String
} derive(ToJson)

///|
pub impl Show for CheckMoonbitProjectResult with output(
  self : CheckMoonbitProjectResult,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.rendered_diagnostics)
}

///|
let schema : @tool.JsonSchema = @tool.JsonSchema::from_json({
  "type": "object",
  "properties": {
    "diagnostic_limit": {
      "type": "integer",
      "description": "The maximum number of diagnostics to return. Default is 10.",
      "default": 10,
    },
    "patch_code": {
      "type": "string",
      "description": "A code snippet to check as if it were appended to the file at 'patch_file'.",
      "default": "",
    },
    "patch_file_name": {
      "type": "string",
      "description": "The file path to check the 'patch_code' against. If not provided, the code will be checked in isolation.",
      "default": "",
    },
    "project_path": {
      "type": "string",
      "description": "The path to the MoonBit project to check. Defaults to the current working directory.",
      "default": ".",
    },
  },
  "required": ["project_path"],
})

///|
pub fn new(cwd : String) -> @tool.Tool[CheckMoonbitProjectResult] {
  @tool.new(
    description="Call MoonBit toolchain to check current MoonBit project, and report any errors. Optionally, you can provide a code snippet and a file path to check the code as if it were appended to that file.",
    name="check_moonbit_project",
    schema~,
    async fn(args) -> @tool.ToolResult[CheckMoonbitProjectResult] noraise {
      let args : CheckMoonbitProjectParams = @json.from_json(args) catch {
        error =>
          return @tool.error(
            "Error: Failed to parse arguments: \{error}",
            error~,
          )
      }
      let resolved_project_path = if @path.is_absolute(args.project_path) {
        args.project_path
      } else {
        @path.join(cwd, args.project_path)
      }
      let diagnostic_limit = args.diagnostic_limit.unwrap_or(10)
      let moon = @moon.Module::load(resolved_project_path) catch {
        error =>
          return @tool.error(
            "Error: Failed to load project at '\{resolved_project_path}': \{error}",
            error~,
          )
      }
      let diagnostics = if args.patch_code is Some(code) &&
        args.patch_file_name is Some(file_path) {
        let resolved_file_path = if @path.is_absolute(file_path) {
          file_path
        } else {
          @path.join(resolved_project_path, file_path)
        }
        moon.check_patch_insert(resolved_file_path, code) catch {
          error =>
            return @tool.error("Error: Failed to check patch: \{error}", error~)
        }
      } else {
        try {
          moon.check()
          moon.diagnostics()
        } catch {
          error =>
            return @tool.error(
              "Error: Failed to check project: \{error}",
              error~,
            )
        }
      }
      if diagnostics.length() == 0 {
        @tool.ok(CheckMoonbitProjectResult::{
          diagnostics,
          diagnostic_limit,
          rendered_diagnostics: "MoonBit project check passed with no diagnostics found.",
        })
      } else {
        let rendered_diagnostics = diagnostics.render(limit=diagnostic_limit)
        @tool.ok(CheckMoonbitProjectResult::{
          diagnostics,
          diagnostic_limit,
          rendered_diagnostics: "MoonBit project check found the following diagnostics:\n\n" +
          "\{rendered_diagnostics}",
        })
      }
    },
  )
}
