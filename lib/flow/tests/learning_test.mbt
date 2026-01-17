// TODO: understand how to use moonbit for tests. just single test.

///|
/// A minimal sanity check that verifies the MoonBit test wiring works.
test "basic" {
  @json.inspect(1 + 1, content=2)
}

///|
