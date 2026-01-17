///|
pub struct ToolDesc {
  description : String
  name : String
  schema : JsonSchema
} derive(ToJson)

///|
pub struct Tool[Output] {
  desc : ToolDesc
  priv f : ToolFn[Output]
}

///|
pub(all) struct ToolFn[Output](async (Json) -> ToolResult[Output] noraise)

///|
pub enum ToolResult[Output] {
  Ok(Output)
  Error(Error, String)
} derive(ToJson)

///|
#as_free_fn
pub fn[Output] ToolResult::ok(output : Output) -> ToolResult[Output] {
  Ok(output)
}

///|
pub impl[Output : Show] Show for ToolResult[Output] with output(
  self : ToolResult[Output],
  logger : &Logger,
) -> Unit {
  match self {
    Ok(output) => logger.write_string(output.to_string())
    Error(ToolFailure(_), message) => logger.write_string(message)
    Error(error, message) =>
      logger.write_string("\{message}\n\{error.to_json().stringify(indent=2)}")
  }
}

///|
priv suberror ToolFailure String derive(ToJson)

///|
#as_free_fn
pub fn[Output] ToolResult::error(
  output : String,
  error? : Error = ToolFailure(output),
) -> ToolResult[Output] {
  Error(error, output)
}

///|
/// 
/// - `description`: Tool description that can be read by the LLM.
/// - `name`: Tool name used by the LLM to call the tool.
/// - `schema`: JSON schema to validate LLM-generated output and provide type information to the LLM.
///             `schema` should be an *object type*. Related issue: [#258](https://github.com/moonbitlang/maria/issues/258)
/// - `f`: Function whose `input` must conform to the `schema` defined above.
///
#as_free_fn
pub fn[Output] Tool::new(
  description~ : String,
  name~ : String,
  schema~ : JsonSchema,
  f : ToolFn[Output],
) -> Tool[Output] {
  Tool::{ desc: { description, name, schema }, f }
}

///|
// TODO(upstream): `as_free_fn` completion not need parens 
#as_free_fn
pub async fn[Output] Tool::call(
  tool : Tool[Output],
  args : Json,
) -> ToolResult[Output] noraise {
  (tool.f)(args)
}

///|
struct AgentTool(Tool[(Json, String)])

///|
pub fn AgentTool::desc(self : AgentTool) -> ToolDesc {
  self.0.desc
}

///|
pub async fn AgentTool::call(
  self : AgentTool,
  args : Json,
) -> ToolResult[(Json, String)] noraise {
  self.0.call(args)
}

///|
/// Convert a Tool[Output] to Tool[Json] by converting outputs to Json
pub fn[Output : ToJson + Show] Tool::to_agent_tool(
  self : Tool[Output],
) -> AgentTool {
  Tool::{
    desc: self.desc,
    f: args => match self.call(args) {
      Ok(output) => Ok((output.to_json(), output.to_string()))
      Error(error, output) => Error(error, output)
    },
  }
}
