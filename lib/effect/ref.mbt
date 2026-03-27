///|
/// Traced mutable references.
/// All mutations record into a TraceBuffer.
///|

///|
pub struct TracedRef[T] {
  name : String
  mut value : T
  trace : Ref[TraceBuffer]
}

///|
pub fn[T] TracedRef::new(
  name : String,
  value : T,
  trace : Ref[TraceBuffer],
) -> TracedRef[T] {
  TracedRef::{ name, value, trace }
}

///| Read the current value.
pub fn[T] TracedRef::get(self : TracedRef[T]) -> T {
  self.value
}

///| Set value and trace.
pub fn[T : Show] TracedRef::set(self : TracedRef[T], value : T) -> Unit {
  let old_value = self.value
  self.value = value
  record_change(self.trace, "set", self.name, old_value, value)
}

///| Set value with location label.
pub fn[T : Show] TracedRef::set_at(self : TracedRef[T], value : T, location : String) -> Unit {
  let old_value = self.value
  self.value = value
  record_change(self.trace, "set", self.name, old_value, value, location=Some(location))
}

///| Update value via function and trace.
pub fn[T : Show] TracedRef::update(self : TracedRef[T], f : (T) -> T) -> Unit {
  let old_value = self.value
  let new_value = f(old_value)
  self.value = new_value
  record_change(self.trace, "update", self.name, old_value, new_value)
}

///| Update value with location label.
pub fn[T : Show] TracedRef::update_at(self : TracedRef[T], f : (T) -> T, location : String) -> Unit {
  let old_value = self.value
  let new_value = f(old_value)
  self.value = new_value
  record_change(self.trace, "update", self.name, old_value, new_value, location=Some(location))
}
