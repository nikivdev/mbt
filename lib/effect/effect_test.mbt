test "succeed and map" {
  let eff : Effect[Unit, Unit, Int] = Effect::succeed(10).map(fn(x) { x * 2 })
  let result = eff.run_unit()
  assert_true(result == Ok(20))
}

test "fail and catch_all" {
  let eff : Effect[Unit, String, Int] = Effect::fail("oops")
    .catch_all(fn(_err) { Effect::succeed(42) })
  let result = eff.run_unit()
  assert_true(result == Ok(42))
}

test "flat_map chains effects" {
  let eff : Effect[Unit, Unit, Int] = Effect::succeed(5)
    .flat_map(fn(x) { Effect::succeed(x + 1) })
    .flat_map(fn(x) { Effect::succeed(x * 2) })
  let result = eff.run_unit()
  assert_true(result == Ok(12))
}

test "provide environment" {
  let eff : Effect[Int, String, Int] = Effect::from(
    fn(env : Int) -> Result[Int, String] { Ok(env * 10) }
  )
  let provided = eff.provide(7)
  let result = provided.run_unit()
  assert_true(result == Ok(70))
}

test "zip combines two effects" {
  let eff1 : Effect[Unit, Unit, Int] = Effect::succeed(1)
  let eff2 : Effect[Unit, Unit, String] = Effect::succeed("hello")
  let zipped = eff1.zip(eff2)
  let result = zipped.run_unit()
  assert_true(result == Ok((1, "hello")))
}

test "map_error transforms error" {
  let eff : Effect[Unit, String, Int] = Effect::fail("bad")
    .map_error(fn(e) { "error: " + e })
  let result = eff.run_unit()
  assert_true(result == Err("error: bad"))
}

test "from_result lifts Ok" {
  let eff : Effect[Unit, String, Int] = Effect::from_result(Ok(99))
  let result = eff.run_unit()
  assert_true(result == Ok(99))
}

test "from_result lifts Err" {
  let eff : Effect[Unit, String, Int] = Effect::from_result(Err("nope"))
  let result = eff.run_unit()
  assert_true(result == Err("nope"))
}
