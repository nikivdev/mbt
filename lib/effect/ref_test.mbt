///|

test "traced ref records mutations" {
  let trace = Ref::new(TraceBuffer::new(10))
  let counter = TracedRef::new("counter", 0, trace)

  TracedRef::update(counter, fn(x) { x + 1 })
  TracedRef::set(counter, 5)
  TracedRef::set_at(counter, 7, "ref_test:set_at")

  let events = snapshot(trace)
  assert_true(events.length() == 3)

  let first = events[0]
  assert_true(first.name == "counter")
  assert_true(first.kind == "update")
  assert_true(first.old_value == "0")
  assert_true(first.new_value == "1")

  let second = events[1]
  assert_true(second.kind == "set")
  assert_true(second.old_value == "1")
  assert_true(second.new_value == "5")

  let third = events[2]
  assert_true(third.location == Some("ref_test:set_at"))
  assert_true(third.old_value == "5")
  assert_true(third.new_value == "7")
}

test "traced ref get returns current value" {
  let trace = Ref::new(TraceBuffer::new(10))
  let r = TracedRef::new("x", 42, trace)

  assert_true(TracedRef::get(r) == 42)
  TracedRef::set(r, 100)
  assert_true(TracedRef::get(r) == 100)
}

test "traced ref update_at records location" {
  let trace = Ref::new(TraceBuffer::new(10))
  let r = TracedRef::new("n", 10, trace)

  TracedRef::update_at(r, fn(x) { x * 2 }, "doubler:line:7")

  let events = snapshot(trace)
  assert_true(events.length() == 1)
  assert_true(events[0].location == Some("doubler:line:7"))
  assert_true(events[0].old_value == "10")
  assert_true(events[0].new_value == "20")
}

test "multiple traced refs share trace buffer" {
  let trace = Ref::new(TraceBuffer::new(10))
  let a = TracedRef::new("a", 1, trace)
  let b = TracedRef::new("b", 100, trace)

  TracedRef::set(a, 2)
  TracedRef::set(b, 200)
  TracedRef::update(a, fn(x) { x + 1 })

  let events = snapshot(trace)
  assert_true(events.length() == 3)
  assert_true(events[0].name == "a")
  assert_true(events[1].name == "b")
  assert_true(events[2].name == "a")
}

test "traced ref with string values" {
  let trace = Ref::new(TraceBuffer::new(10))
  let msg = TracedRef::new("message", "hello", trace)

  TracedRef::set(msg, "world")
  TracedRef::update(msg, fn(s) { s + "!" })

  assert_true(TracedRef::get(msg) == "world!")

  let events = snapshot(trace)
  assert_true(events[0].old_value == "hello")
  assert_true(events[0].new_value == "world")
  assert_true(events[1].old_value == "world")
  assert_true(events[1].new_value == "world!")
}
