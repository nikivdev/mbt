///|

test "trace buffer wraps and keeps order" {
  let trace = Ref::new(TraceBuffer::new(2))
  record_change(trace, "set", "a", 1, 2)
  record_change(trace, "set", "a", 2, 3)
  record_change(trace, "set", "a", 3, 4)

  let events = snapshot(trace)
  assert_true(events.length() == 2)
  // oldest -> newest
  assert_true(events[0].old_value == "2")
  assert_true(events[0].new_value == "3")
  assert_true(events[1].old_value == "3")
  assert_true(events[1].new_value == "4")
}

test "trace buffer default capacity" {
  let trace = Ref::new(TraceBuffer::new(0))
  // Default capacity is 128 when 0 or negative
  assert_true(trace.val.capacity == 128)
}

test "trace buffer empty snapshot" {
  let trace = Ref::new(TraceBuffer::new(10))
  let events = snapshot(trace)
  assert_true(events.length() == 0)
}

test "trace records location" {
  let trace = Ref::new(TraceBuffer::new(10))
  record(trace, "custom", "x", "old", "new", location=Some("test.mbt:42"))

  let events = snapshot(trace)
  assert_true(events.length() == 1)
  assert_true(events[0].location == Some("test.mbt:42"))
  assert_true(events[0].kind == "custom")
}

test "trace sequence numbers increment" {
  let trace = Ref::new(TraceBuffer::new(10))
  record_change(trace, "a", "x", 1, 2)
  record_change(trace, "b", "y", 3, 4)
  record_change(trace, "c", "z", 5, 6)

  let events = snapshot(trace)
  assert_true(events[0].seq == 1)
  assert_true(events[1].seq == 2)
  assert_true(events[2].seq == 3)
}
