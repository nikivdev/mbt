///|
async test "get_moonbit_mbti" (t : @test.Test) {
  @mock.run(t, taco => {
    @moon.new(taco.cwd.path(), name="test_get_moonbit_mbti")
    let get_moonbit_mbti = @get_moonbit_mbti.new(taco.cwd.path())
    let result = get_moonbit_mbti.call({ "package": "moonbitlang/core/set" })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output.split("\n")[0:12].to_array().join("\n"),
      content=(
        #|// Generated using `moon info`, DON'T EDIT IT
        #|package "moonbitlang/core/set"
        #|
        #|// Values
        #|
        #|// Errors
        #|
        #|// Types and methods
        #|type Set[K]
        #|#alias(insert, deprecated)
        #|fn[K : Hash + Eq] Set::add(Self[K], K) -> Unit
        #|fn[K : Hash + Eq] Set::add_and_check(Self[K], K) -> Bool
      ),
    )
  })
}
