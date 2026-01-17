///|
let schema : @tool.JsonSchema = @tool.JsonSchema::from_json({
  "type": "object",
  "properties": {
    "package": {
      "type": "string",
      "description": "The name of the package to analyze (e.g. 'moonbitlang/core/set`').",
    },
  },
  "required": ["package"],
})

///|
pub fn new(cwd : String) -> @tool.Tool[String] {
  @tool.new(
    name="get_moonbit_mbti",
    description="Get Moonbit MBTI",
    schema~,
    @tool.ToolFn(async fn(args) -> @tool.ToolResult[String] noraise {
      guard args is { "package": String(pkg_name), .. } else {
        @tool.error(
          "Error: 'package' argument is required and must be a string.",
        )
      }
      let moon = @moon.Module::load(cwd) catch {
        error =>
          return @tool.error(
            "Error: Failed to load module at '\{cwd}': \{error}",
            error~,
          )
      }
      guard (moon.find_package(pkg_name) catch {
          error =>
            return @tool.error(
              "Error: Failed to find package '\{pkg_name}': \{error}",
              error~,
            )
        })
        is Some(pkg) else {
        @tool.error("Error: Package '\{pkg_name}' not found in module.")
      }
      let interface = pkg.interface() catch {
        error =>
          return @tool.error(
            "Error: Failed to get interface for package '\{pkg_name}': \{error}",
            error~,
          )
      }
      @tool.ok(interface)
    }),
  )
}
