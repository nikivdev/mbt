///|
/// Converts a JSON value to XML format and appends the result to an output
/// array.
///
/// Parameters:
///
/// * `json` : The JSON value to convert to XML format.
/// * `indent` : The number of spaces to use for indentation (defaults to 0).
/// * `output` : The array to append the XML lines to.
///
/// Returns nothing as this function writes directly to the `output` array.
fn json2xml(json : Json, indent? : Int = 0, output : Array[String]) -> Unit {
  match json {
    Object(object) =>
      for key, value in object {
        output.push(" ".repeat(indent) + "<\{key}>")
        json2xml(value, indent=indent + 2, output)
        output.push(" ".repeat(indent) + "</\{key}>")
      }
    Array(array) =>
      // TODO: it might be not correct to just output array items directly, but
      // for now this is much more readable than:
      //
      // ```xml
      // <item>
      //   ...
      // </item>
      // <item>
      //   ...
      // </item>
      // ...
      // ```
      //
      // so we keep it as is.
      for item in array {
        json2xml(item, indent~, output)
      }
    String(string) =>
      for line in string.split("\n") {
        if line.is_empty() {
          output.push("")
        } else {
          output.push([.." ".repeat(indent), ..line])
        }
      }
    Number(_, repr=Some(repr)) => output.push(" ".repeat(indent) + repr)
    Number(value, repr=None) =>
      output.push(" ".repeat(indent) + value.to_string())
    True => output.push(" ".repeat(indent) + "true")
    False => output.push(" ".repeat(indent) + "false")
    Null => output.push(" ".repeat(indent) + "null")
  }
}

///|
test "json2xml" {
  let lines = []
  json2xml({ "greeting": "hello", "items": [1, 2, 3], "active": true }, lines)
  inspect(
    lines.join("\n"),
    content=(
      #|<greeting>
      #|  hello
      #|</greeting>
      #|<items>
      #|  1
      #|  2
      #|  3
      #|</items>
      #|<active>
      #|  true
      #|</active>
    ),
  )
  lines.clear()
  json2xml([1, "A", true, null], lines)
  inspect(
    lines.join("\n"),
    content=(
      #|1
      #|A
      #|true
      #|null
    ),
  )
}
