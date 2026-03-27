///|
/// Minimal Effect core for MoonBit (POC).
///
/// Effect[R, E, A] represents a computation that requires an environment R,
/// may fail with E, and produces A.
///
/// This is intentionally small and native (no runtime).
///
///|
pub struct Effect[R, E, A] {
  run : (R) -> Result[A, E]
}

///| Create an Effect from a function.
pub fn[R, E, A] Effect::from(f : (R) -> Result[A, E]) -> Effect[R, E, A] {
  Effect::{ run: f }
}

///| Succeed with a value.
pub fn[R, E, A] Effect::succeed(value : A) -> Effect[R, E, A] {
  Effect::{ run: fn(_ : R) -> Result[A, E] { Ok(value) } }
}

///| Fail with an error.
pub fn[R, E, A] Effect::fail(error : E) -> Effect[R, E, A] {
  Effect::{ run: fn(_ : R) -> Result[A, E] { Err(error) } }
}

///| Lift an existing Result into Effect.
pub fn[R, E, A] Effect::from_result(result : Result[A, E]) -> Effect[R, E, A] {
  Effect::{ run: fn(_ : R) -> Result[A, E] { result } }
}

///| Map success value.
pub fn[R, E, A, B] Effect::map(self : Effect[R, E, A], f : (A) -> B) -> Effect[R, E, B] {
  Effect::{ run: fn(env : R) -> Result[B, E] {
    match (self.run)(env) {
      Ok(value) => Ok(f(value))
      Err(err) => Err(err)
    }
  }}
}

///| FlatMap / chain.
pub fn[R, E, A, B] Effect::flat_map(
  self : Effect[R, E, A],
  f : (A) -> Effect[R, E, B],
) -> Effect[R, E, B] {
  Effect::{ run: fn(env : R) -> Result[B, E] {
    match (self.run)(env) {
      Ok(value) => (f(value).run)(env)
      Err(err) => Err(err)
    }
  }}
}

///| Map error.
pub fn[R, E, A, E2] Effect::map_error(
  self : Effect[R, E, A],
  f : (E) -> E2,
) -> Effect[R, E2, A] {
  Effect::{ run: fn(env : R) -> Result[A, E2] {
    match (self.run)(env) {
      Ok(value) => Ok(value)
      Err(err) => Err(f(err))
    }
  }}
}

///| Recover from errors.
pub fn[R, E, A, E2] Effect::catch_all(
  self : Effect[R, E, A],
  f : (E) -> Effect[R, E2, A],
) -> Effect[R, E2, A] {
  Effect::{ run: fn(env : R) -> Result[A, E2] {
    match (self.run)(env) {
      Ok(value) => Ok(value)
      Err(err) => (f(err).run)(env)
    }
  }}
}

///| Provide a fixed environment.
pub fn[R, E, A] Effect::provide(self : Effect[R, E, A], env : R) -> Effect[Unit, E, A] {
  Effect::{ run: fn(_ : Unit) -> Result[A, E] { (self.run)(env) } }
}

///| Zip two effects in sequence.
pub fn[R, E, A, B] Effect::zip(
  self : Effect[R, E, A],
  other : Effect[R, E, B],
) -> Effect[R, E, (A, B)] {
  Effect::{ run: fn(env : R) -> Result[(A, B), E] {
    match (self.run)(env) {
      Ok(a) =>
        match (other.run)(env) {
          Ok(b) => Ok((a, b))
          Err(err) => Err(err)
        }
      Err(err) => Err(err)
    }
  }}
}

///| Run effect with environment.
pub fn[R, E, A] Effect::run_with(self : Effect[R, E, A], env : R) -> Result[A, E] {
  (self.run)(env)
}

///| Run effect with Unit environment.
pub fn[E, A] Effect::run_unit(self : Effect[Unit, E, A]) -> Result[A, E] {
  (self.run)(())
}
