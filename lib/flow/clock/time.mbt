///|
struct Epoch {}

///|
pub let epoch : Epoch = Epoch::{  }

///|
pub impl Clock for Epoch with now(_ : Epoch) -> Int64 {
  @async.now()
}

///|
pub impl Clock for Epoch with now_str(clock : Epoch) -> String {
  @time.unix(clock.now() / 1000).to_plain_date_time().to_string() catch {
    err => "Time error: \{err}"
  }
}

///|
pub(open) trait Clock {
  now(self : Self) -> Int64
  now_str(self : Self) -> String
}
