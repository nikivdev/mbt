///|
pub impl Show for MetaWriteToFileResult with output(
  self : MetaWriteToFileResult,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.message)
  logger.write_char('\n')
  if self.diff is Some(diff) && !diff.is_blank() {
    if self.learning_prompt is Some(_) {
      logger.write_string(
        "\n**Changes made during formatting/fixing:**\n\n```diff\n",
      )
    } else {
      logger.write_string("\n**Changes made during formatting:**\n\n```diff\n")
    }
    logger.write_string(diff.trim_space().to_string())
    logger.write_string("\n```\n")
  }
  if self.learning_prompt is Some(learning_prompt) {
    logger.write_char('\n')
    logger.write_string(learning_prompt)
    logger.write_char('\n')
  }
}

///|
test "MetaWriteToFileResult::Show" {
  let result = MetaWriteToFileResult::{
    path: "/var/folders/jb/64x3jtc51qbfk3y1m9f3yvyc0000gn/T/maria-test-smJHF4P/json_parser/json_parser/moon.pkg.json",
    message: "File written successfully to json_parser/json_parser/moon.pkg.json",
    diff: Some(
      "@@ -1,5 +1,5 @@\n {\n-  \"name\": \"json_parser\",\n+  \"name\": \"json_parser_updated\",\n   \"version\": \"0.1.0\",\n   \"dependencies\": {\n     \"moonbitlang/maria\": \"^0.1.0\"\n   }\n }",
    ),
    learning_prompt: Some(
      (
        #|**⚠️ Syntax Error Learning Note:**
        #|
        #|The file had syntax errors that were automatically fixed. Please review the changes to ensure correctness.
      ),
    ),
  }
  @json.inspect(result, content={
    "path": "/var/folders/jb/64x3jtc51qbfk3y1m9f3yvyc0000gn/T/maria-test-smJHF4P/json_parser/json_parser/moon.pkg.json",
    "message": "File written successfully to json_parser/json_parser/moon.pkg.json",
    "diff": "@@ -1,5 +1,5 @@\n {\n-  \"name\": \"json_parser\",\n+  \"name\": \"json_parser_updated\",\n   \"version\": \"0.1.0\",\n   \"dependencies\": {\n     \"moonbitlang/maria\": \"^0.1.0\"\n   }\n }",
    "learning_prompt": "**⚠️ Syntax Error Learning Note:**\n\nThe file had syntax errors that were automatically fixed. Please review the changes to ensure correctness.",
  })
  let result_no_diff = { ..result, diff: None }
  @json.inspect(result_no_diff, content={
    "path": "/var/folders/jb/64x3jtc51qbfk3y1m9f3yvyc0000gn/T/maria-test-smJHF4P/json_parser/json_parser/moon.pkg.json",
    "message": "File written successfully to json_parser/json_parser/moon.pkg.json",
    "learning_prompt": "**⚠️ Syntax Error Learning Note:**\n\nThe file had syntax errors that were automatically fixed. Please review the changes to ensure correctness.",
  })
  inspect(
    result,
    content=(
      #|File written successfully to json_parser/json_parser/moon.pkg.json
      #|
      #|**Changes made during formatting/fixing:**
      #|
      #|```diff
      #|@@ -1,5 +1,5 @@
      #| {
      #|-  "name": "json_parser",
      #|+  "name": "json_parser_updated",
      #|   "version": "0.1.0",
      #|   "dependencies": {
      #|     "moonbitlang/maria": "^0.1.0"
      #|   }
      #| }
      #|```
      #|
      #|**⚠️ Syntax Error Learning Note:**
      #|
      #|The file had syntax errors that were automatically fixed. Please review the changes to ensure correctness.
      #|
    ),
  )
}
