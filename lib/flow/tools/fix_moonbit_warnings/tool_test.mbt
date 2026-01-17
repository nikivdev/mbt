///|
/// FIXME: reenable
#cfg(false)
async test "fix_moonbit_warnings" (t : @test.Test) {
  @mock.run(t, mock => {
    let model = mock.model(name=ClaudeHaiku4_5)
    mock
    .add_file("moon.mod.json")
    .write_string(
      Json::object({
        "name": "username/example",
        "version": "0.1.0",
        "entry": "main.moon",
        "dependencies": {},
      }).stringify(indent=2),
    )
    let list_pkg = mock.add_directory("list")
    list_pkg
    .add_file("moon.pkg.json")
    .write_string(Json::object({}).stringify(indent=2))
    list_pkg
    .add_file("types.mbt")
    .write_string(
      (
        #|#alias(T, deprecated)
        #|pub enum List[A] {
        #|  Empty
        #|  More(A, mut tail~ : List[A])
        #|} derive(Eq)
      ),
    )
    list_pkg
    .add_file("list.mbt")
    .write_string(
      (
        #|///|
        #|/// Get the length of the list.
        #|#alias(length, deprecated)
        #|pub fn[A] List::len(self : List[A]) -> Int {
        #|  loop (self, 0) {
        #|    (Empty, len) => len
        #|    (More(_, tail=rest), acc) => continue (rest, acc + 1)
        #|  }
        #|}
        #|
        #|///|
        #|/// ToJson implementation for List.
        #|/// Converts a list to a JSON array.
        #|pub impl[A : ToJson] ToJson for List[A] with to_json(self) {
        #|  let capacity = self.length()
        #|  guard capacity != 0 else { return [] }
        #|  let jsons = Array::new(capacity~)
        #|  for a in self {
        #|    jsons.push(a.to_json())
        #|  }
        #|  Json::array(jsons)
        #|}
        #|
        #|
        #|///|
        #|/// Maps the list.
        #|pub fn[A, B] List::map(self : List[A], f : (A) -> B raise?) -> List[B] raise? {
        #|  match self {
        #|    Empty => Empty
        #|    More(hd, tail~) => {
        #|      let dest = More(f(hd), tail=Empty)
        #|      loop (dest, tail) {
        #|        (_, Empty) => ()
        #|        (More(_) as dest, More(hd, tail~)) => {
        #|          dest.tail = More(f(hd), tail=Empty)
        #|          continue (dest.tail, tail)
        #|        }
        #|        // unreachable
        #|        (Empty, _) => panic()
        #|      }
        #|      dest
        #|    }
        #|  }
        #|}
        #|
        #|
        #|///|
        #|/// Create an iterator over the list elements.
        #|///
        #|/// Returns an iterator that yields each element of the list in order.
        #|pub fn[A] List::iterator(self : List[A]) -> Iterator[A] {
        #|  let mut next = self
        #|  Iterator::new(fn() {
        #|    match next {
        #|      Empty => None
        #|      More(head, tail~) => {
        #|        next = tail
        #|        Some(head)
        #|      }
        #|    }
        #|  })
        #|}
        #|
      ),
    )
    let moon = @moon.Module::load(mock.cwd.path())
    moon.check()
    @json.inspect(mock.json(moon.diagnostics()), content=[
      "Diagnostics",
      [
        {
          "error_code": 2000,
          "level": "Warning",
          "loc": {
            "end": { "col": 29, "line": 15 },
            "path": "(mock:cwd)/list/list.mbt",
            "start": { "col": 23, "line": 15 },
          },
          "message": "Warning (Alert deprecated): `length` is deprecated, use `len` instead",
        },
      ],
    ])
    let agent = @agent.new(model, cwd=mock.cwd.path(), logger=mock.logger)
    let tool = @fix_moonbit_warnings.new(agent)
    let args : Json = {
      "project_path": mock.cwd.path(),
      "description": "Fix all MoonBit warnings/errors in the project.",
    }
    let output = tool.call(args)
    guard output is Ok(result) else {
      fail("Expected tool call to succeed, got error: \{output}")
      return
    }
    inspect(result, content="Processed 2 files and updated 0 segments.")
  })
}
