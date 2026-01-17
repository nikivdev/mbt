///|
async test "goto_definition" (t : @test.Test) {
  @mock.run(t, mock => {
    mock.add_files([
      (
        "moon.mod.json",
        { "name": "username/example", "version": "0.1.0" }
        .to_json()
        .stringify(indent=2),
      ),
      ("moon.pkg.json", Json::object({}).stringify(indent=2)),
      (
        "main.mbt",
        (
          #|///|
          #|pub fn greet(name : String) -> String {
          #|  println("Hello, \{name}!")
          #|}
        ),
      ),
    ])
    inspect(
      mock.show(goto_definition("@username/example greet", mock.cwd.path())),
      content=(
        #|Search completed using fuzzy symbolic search for MoonBit definitions.
        #|Note: The search pattern "@username/example greet" was used for fuzzy matching of symbol names.
        #|
        #|There are total 1 symbols match query '@username/example greet':
        #|Top 1 best-matching symbols:
        #|
        #|`pub fn greet` in package username/example at (mock:cwd)/main.mbt:1-4:
        #|        ^^^^^             ^^^^^^^^^^^^^^^^
        #|1 | ///|
        #|  | pub fn greet(name : String) -> String {
        #|  |   println("Hello, \{name}!")
        #|  | }
        #|
        #|
      ),
    )
    inspect(
      mock.show(goto_definition("@username/example json", mock.cwd.path())),
      content=(
        #|Error: No matching symbols found for query '@username/example json'
        #|
      ),
    )
  })
}

///|
async test "find_references" (t : @test.Test) {
  @mock.run(t, mock => {
    mock.add_files([
      (
        "moon.mod.json",
        { "name": "username/example", "version": "0.1.0" }
        .to_json()
        .stringify(indent=2),
      ),
      ("moon.pkg.json", Json::object({}).stringify(indent=2)),
      (
        "main.mbt",
        (
          #|///|
          #|pub fn greet(name : String) -> String {
          #|  println("Hello, \{name}!")
          #|}
          #|
          #|fn main {
          #|  greet("World")
          #|  greet("MoonBit")
          #|}
        ),
      ),
    ])
    inspect(
      mock.show(find_references("greet", mock.cwd.path())),
      content=(
        #|Search completed using MoonBit IDE find-references tool.
        #|Query: "greet"
        #|Working directory: (mock:cwd)
        #|
        #|`pub fn greet` in package username/example at (mock:cwd)/main.mbt:1-4:
        #|        ^^^^^
        #|1 | ///|
        #|  | pub fn greet(name : String) -> String {
        #|  |   println("Hello, \{name}!")
        #|  | }
        #|
        #|Found 5 references of this symbol:
        #|(mock:cwd)/main.mbt:2:8-2:13:
        #|  | ///|
        #|2 | pub fn greet(name : String) -> String {
        #|  |        ^^^^^
        #|  |   println("Hello, \{name}!")
        #|  | }
        #|
        #|(mock:cwd)/main.mbt:7:3-7:8:
        #|  | }
        #|  | 
        #|  | fn main {
        #|7 |   greet("World")
        #|  |   ^^^^^
        #|  |   greet("MoonBit")
        #|  | }
        #|
        #|(mock:cwd)/main.mbt:8:3-8:8:
        #|  | 
        #|  | fn main {
        #|  |   greet("World")
        #|8 |   greet("MoonBit")
        #|  |   ^^^^^
        #|  | }
        #|
        #|(mock:cwd)/main.mbt:7:3-7:8:
        #|  | }
        #|  | 
        #|  | fn main {
        #|7 |   greet("World")
        #|  |   ^^^^^
        #|  |   greet("MoonBit")
        #|  | }
        #|
        #|(mock:cwd)/main.mbt:8:3-8:8:
        #|  | 
        #|  | fn main {
        #|  |   greet("World")
        #|8 |   greet("MoonBit")
        #|  |   ^^^^^
        #|  | }
        #|
        #|
      ),
    )
  })
}
