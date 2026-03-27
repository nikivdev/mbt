///|
/// Mutation tracing for Effect (POC).
///
/// Always-on, low-cost tracing of state changes.
/// Use a TraceBuffer in your environment and route all mutations through
/// TracedRef / helpers so changes are recorded.
///
/// Location is optional and can be filled later (e.g. callsite, file:line).
///|

///|
pub struct TraceEvent {
  seq : Int
  kind : String
  name : String
  old_value : String
  new_value : String
  location : String?
} derive(Show)

///|
pub struct TraceBuffer {
  capacity : Int
  mut next_seq : Int
  mut cursor : Int
  items : Array[TraceEvent]
}

///|
pub fn TraceBuffer::new(capacity : Int) -> TraceBuffer {
  let cap = if capacity <= 0 { 128 } else { capacity }
  TraceBuffer::{
    capacity: cap,
    next_seq: 1,
    cursor: 0,
    items: [],
  }
}

///|
/// Record a mutation event (internal).
pub fn record(
  trace : Ref[TraceBuffer],
  kind : String,
  name : String,
  old_value : String,
  new_value : String,
  location~ : String? = None,
) -> Unit {
  let buf = trace.val
  let event = TraceEvent::{
    seq: buf.next_seq,
    kind,
    name,
    old_value,
    new_value,
    location,
  }
  buf.next_seq = buf.next_seq + 1

  if buf.items.length() < buf.capacity {
    buf.items.push(event)
    if buf.items.length() == buf.capacity {
      buf.cursor = 0
    } else {
      buf.cursor = buf.items.length()
    }
  } else {
    buf.items[buf.cursor] = event
    buf.cursor = (buf.cursor + 1) % buf.capacity
  }

  trace.val = buf
}

///|
/// Record a mutation with typed values.
pub fn[T : Show] record_change(
  trace : Ref[TraceBuffer],
  kind : String,
  name : String,
  old_value : T,
  new_value : T,
  location~ : String? = None,
) -> Unit {
  record(
    trace,
    kind,
    name,
    old_value.to_string(),
    new_value.to_string(),
    location~,
  )
}

///|
/// Snapshot events in chronological order (oldest -> newest).
pub fn snapshot(trace : Ref[TraceBuffer]) -> Array[TraceEvent] {
  let buf = trace.val
  if buf.items.length() < buf.capacity {
    return buf.items
  }
  let ordered : Array[TraceEvent] = []
  let mut i = buf.cursor
  let mut count = 0
  while count < buf.items.length() {
    ordered.push(buf.items[i])
    i = (i + 1) % buf.items.length()
    count += 1
  }
  ordered
}
