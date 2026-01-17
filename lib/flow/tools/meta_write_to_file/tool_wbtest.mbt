///|
async test "render_diagnostics" {
  let path = "json_parser/json_parser.mbt"
  let content =
    #|///|
    #|let x : Int = "String",
    #|
    #|///|
    #|let y : Int = 3
  let diagnostics = @moon.check_syntax_of_string(path~, content)
  inspect(
    diagnostics.render(
      context=3,
      limit=DiagnosticLimit,
      overlay=Map::from_array([(@path.basename(path).to_string(), content)]),
    ),
    content=(
      #|error[3002]: json_parser.mbt:3:2: Parse error, unexpected token `,`, you may expect `pub`, `priv`, `type`, `suberror`, `typealias`, `async`, `fn`, `fnalias`, `struct`, `enum`, `let`, `const`, `extern`, `test`, `impl`, `trait`, `traitalias`, `enumview`, `#attribute` or `using`.
      #|   │ ///|
      #|   │ let x : Int = "String",
      #| 3 │
      #|   │  ^
      #|   │ ///|
    ),
  )
  let content =
    #|
    #|///|
    #|let z = 1
    #|
    #|///|
    #|let x : Int = ("String"aaa
    #|
    #|///|
    #|let y : Int = 3
  let diagnostics = @moon.check_syntax_of_string(path~, content)
  inspect(
    diagnostics.render(
      context=3,
      limit=DiagnosticLimit,
      overlay=Map::from_array([(@path.basename(path).to_string(), content)]),
    ),
    content=(
      #|error[3002]: json_parser.mbt:6:24-27: Parse error, unexpected token id (lowercase start), you may expect `,` or `)`.
      #|   │ let z = 1
      #|   │
      #|   │ ///|
      #| 6 │ let x : Int = ("String"aaa
      #|   │                        ^^^
      #|   │
      #|   │ ///|
    ),
  )
  let path = "main.mbt"
  let content =
    #|enum Color {
    #|  Red,
    #|  Green,
    #|  Blue,
    #|}
    #|
    #|fn Color::to_string(self : Color) -> String {
    #|  switch self {
    #|    Red => "red",
    #|    Green => "green",
    #|    Blue => "blue",
    #|  }
    #|}
    #|
    #|fn main() {
    #|
    #|  let color : Color = Blue
    #|  println(color.to_string())
    #|}
  let diagnostics = @moon.check_syntax_of_string(path~, content)
  inspect(
    diagnostics.render(
      context=3,
      limit=DiagnosticLimit,
      overlay=Map::from_array([(@path.basename(path).to_string(), content)]),
    ),
    content=(
      #|error[3800]: main.mbt:2:6-7: Expecting a newline or `;` here, but encountered `,`.
      #|   │ enum Color {
      #| 2 │   Red,
      #|   │      ^
      #|   │   Green,
      #|   │   Blue,
      #|   │ }
      #|
      #|error[3800]: main.mbt:3:8-9: Expecting a newline or `;` here, but encountered `,`.
      #|   │ enum Color {
      #|   │   Red,
      #| 3 │   Green,
      #|   │        ^
      #|   │   Blue,
      #|   │ }
      #|   │
      #|
      #|error[3800]: main.mbt:4:7-8: Expecting a newline or `;` here, but encountered `,`.
      #|   │ enum Color {
      #|   │   Red,
      #|   │   Green,
      #| 4 │   Blue,
      #|   │       ^
      #|   │ }
      #|   │
      #|   │ fn Color::to_string(self : Color) -> String {
      #|
      #|error[3002]: main.mbt:8:10-14: Parse error, unexpected token id (lowercase start), you may expect `;` or `}`.
      #|    │ }
      #|    │
      #|    │ fn Color::to_string(self : Color) -> String {
      #|  8 │   switch self {
      #|    │          ^^^^
      #|    │     Red => "red",
      #|    │     Green => "green",
      #|    │     Blue => "blue",
      #|
      #|error[3002]: main.mbt:14:2: Parse error, unexpected token `}`, you may expect `pub`, `priv`, `type`, `suberror`, `typealias`, `async`, `fn`, `fnalias`, `struct`, `enum`, `let`, `const`, `extern`, `test`, `impl`, `trait`, `traitalias`, `enumview`, `#attribute` or `using`.
      #|    │     Blue => "blue",
      #|    │   }
      #|    │ }
      #| 14 │
      #|    │  ^
      #|    │ fn main() {
      #|    │
      #|    │   let color : Color = Blue
      #|
      #|error[3003]: main.mbt:15:8-10: Unused parameter list for the main function. The syntax is `fn main { ... }`
      #|    │   }
      #|    │ }
      #|    │
      #| 15 │ fn main() {
      #|    │        ^^
      #|    │
      #|    │   let color : Color = Blue
      #|    │   println(color.to_string())
    ),
  )
}
