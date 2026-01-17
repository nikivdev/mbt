///|
async test "check_moonbit_project" (t : @test.Test) {
  @mock.run(t, taco => {
    taco.add_files([
      (
        "moon.mod.json",
        { "name": "example", "version": "0.1.0" }.to_json().stringify(),
      ),
      ("moon.pkg.json", Json::object({}).stringify()),
      (
        "example.mbt",
        (
          #|///|
          #|let x : Int = "string"
        ),
      ),
    ])
    let args = input_json(diagnostic_limit=10, project_path=taco.cwd.path())
    let result = new(taco.cwd.path()).call(args)
    @json.inspect(taco.json(result), content=[
      "Ok",
      {
        "diagnostics": [
          "Diagnostics",
          [
            {
              "error_code": 2,
              "level": "Warning",
              "loc": {
                "end": { "col": 6, "line": 2 },
                "path": "(mock:cwd)/example.mbt",
                "start": { "col": 5, "line": 2 },
              },
              "message": "Warning: Unused variable 'x'",
            },
            {
              "error_code": 4014,
              "level": "Error",
              "loc": {
                "end": { "col": 23, "line": 2 },
                "path": "(mock:cwd)/example.mbt",
                "start": { "col": 15, "line": 2 },
              },
              "message": "Expr Type Mismatch\n        has type : String\n        wanted   : Int",
            },
          ],
        ],
        "diagnostic_limit": 10,
        "rendered_diagnostics": "MoonBit project check found the following diagnostics:\n\nerror[4014]: (mock:cwd)/example.mbt:2:15-23: Expr Type Mismatch\n        has type : String\n        wanted   : Int\n 2 │ let x : Int = \"string\"\n   │               ^^^^^^^^\n\nwarning[0002]: (mock:cwd)/example.mbt:2:5-6: Warning: Unused variable 'x'\n 2 │ let x : Int = \"string\"\n   │     ^",
      },
    ])
    inspect(
      taco.show(result),
      content=(
        #|MoonBit project check found the following diagnostics:
        #|
        #|error[4014]: (mock:cwd)/example.mbt:2:15-23: Expr Type Mismatch
        #|        has type : String
        #|        wanted   : Int
        #| 2 │ let x : Int = "string"
        #|   │               ^^^^^^^^
        #|
        #|warning[0002]: (mock:cwd)/example.mbt:2:5-6: Warning: Unused variable 'x'
        #| 2 │ let x : Int = "string"
        #|   │     ^
      ),
    )
  })
}

///|
async test "check_moonbit_project/patch-insert" (t : @test.Test) {
  @mock.run(t, taco => {
    taco.add_files([
      (
        "moon.mod.json",
        { "name": "example", "version": "0.1.0" }.to_json().stringify(),
      ),
      ("moon.pkg.json", Json::object({}).stringify()),
      (
        "example.mbt",
        (
          #|///|
          #|let x : Int = "string"
          #|
        ),
      ),
    ])
    let args = input_json(
      diagnostic_limit=10,
      project_path=taco.cwd.path(),
      patch_code="let y : String = 42",
      patch_file_name="example.mbt",
    )
    let result = new(taco.cwd.path()).call(args)

    // Note we don't really change the file
    inspect(
      @fsx.read_file(@path.join(taco.cwd.path(), "example.mbt")),
      content=(
        #|///|
        #|let x : Int = "string"
        #|
      ),
    )
    @json.inspect(taco.json(result), content=[
      "Ok",
      {
        "diagnostics": [
          "Diagnostics",
          [
            {
              "error_code": 2,
              "level": "Warning",
              "loc": {
                "end": { "col": 6, "line": 1 },
                "path": "(mock:cwd)/example.mbt",
                "start": { "col": 5, "line": 1 },
              },
              "message": "Warning: Unused variable 'y'",
            },
            {
              "error_code": 4014,
              "level": "Error",
              "loc": {
                "end": { "col": 20, "line": 1 },
                "path": "(mock:cwd)/example.mbt",
                "start": { "col": 18, "line": 1 },
              },
              "message": "Expr Type Mismatch\n        has type : Int\n        wanted   : String",
            },
          ],
        ],
        "diagnostic_limit": 10,
        "rendered_diagnostics": "MoonBit project check found the following diagnostics:\n\nerror[4014]: (mock:cwd)/example.mbt:1:18-20: Expr Type Mismatch\n        has type : Int\n        wanted   : String\n 1 │ ///|\n   │                  ^^\n\nwarning[0002]: (mock:cwd)/example.mbt:1:5-6: Warning: Unused variable 'y'\n 1 │ ///|\n   │     ^",
      },
    ])
    inspect(
      taco.show(result),
      content=(
        #|MoonBit project check found the following diagnostics:
        #|
        #|error[4014]: (mock:cwd)/example.mbt:1:18-20: Expr Type Mismatch
        #|        has type : Int
        #|        wanted   : String
        #| 1 │ ///|
        #|   │                  ^^
        #|
        #|warning[0002]: (mock:cwd)/example.mbt:1:5-6: Warning: Unused variable 'y'
        #| 1 │ ///|
        #|   │     ^
      ),
    )
  })
}
