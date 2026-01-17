///|
fn count_maximum_contiguous_backticks(content : String) -> Int raise {
  let regexp = @regexp.compile("(`+)")
  let mut maximum_backticks = 0
  loop regexp.execute(content) {
    matched =>
      if matched.get(0) is Some(backticks) {
        maximum_backticks = @cmp.maximum(maximum_backticks, backticks.length())
        continue regexp.execute(matched.after())
      } else {
        break
      }
  }
  maximum_backticks
}

///|
test "count_maximum_contiguous_backticks" {
  @json.inspect(
    count_maximum_contiguous_backticks("No backticks here"),
    content=0,
  )
  @json.inspect(
    count_maximum_contiguous_backticks("Here is `one` backtick"),
    content=1,
  )
  @json.inspect(
    count_maximum_contiguous_backticks(
      (
        #|Some text
        #|
        #|```moonbit
        #|fn main {
        #|  println("Hello, world!")
        #|}
        #|```
      ),
    ),
    content=3,
  )
}
