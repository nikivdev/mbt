///|
async test "get_moonbit_coverage" (t : @test.Test) {
  @mock.run(t, timeout=300_000, taco => {
    taco.add_files([
      (
        "moon.mod.json",
        (
          #|{ "name": "example", "version": "0.1.0" }
        ),
      ),
      (
        "moon.pkg.json",
        (
          #|{ }
        ),
      ),
      (
        "example.mbt",
        (
          #|///|
          #|pub fn fib(n : Int) -> Int {
          #|  if n <= 1 {
          #|    n
          #|  } else {
          #|    fib(n - 1) + fib(n - 2)
          #|  }
          #|}
        ),
      ),
      (
        "example_test.mbt",
        (
          #|///|
          #|test "fib" {
          #|  @json.inspect(@example.fib(1), content=1)
          #|}
        ),
      ),
    ])
    let params = params(project_path=taco.cwd.path(), file="example.mbt")
    let tool = new(taco.cwd.path())
    let result = tool.call(params.to_json())
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(
      output.content,
      content=(
        $|Total: 1 uncovered line(s) in 1 file(s)
        $|
        $|1 uncovered line(s) in example.mbt:
        $|
        $|  | pub fn fib(n : Int) -> Int {
        $|  |   if n <= 1 {
        $|  |     n
        $|  |   } else {
        $|6 |     fib(n - 1) + fib(n - 2)
        $|  |     ^^^^^^^^^^^^^^^^^^^^^^^ 	<-- UNCOVERED
        $|  |   }
        $|  | }
        $|  …
        $|
        $|Total: 1 uncovered line(s) in 1 file(s)
        $|
      ),
    )
  })
}
