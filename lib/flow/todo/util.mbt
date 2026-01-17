///|
pub fn Priority::icon(self : Priority) -> String {
  match self {
    High => "🔴"
    Medium => "🟡"
    Low => "🟢"
  }
}

///|
pub fn Status::icon(self : Status) -> String {
  match self {
    Completed => "✅"
    InProgress => "🔄"
    Pending => "⏳"
  }
}
