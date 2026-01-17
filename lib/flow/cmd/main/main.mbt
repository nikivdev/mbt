///|
async fn main {
  @backtrace.initialize()
  let args = @os.args()
  match args[1:] {
    ["migrate", .. rest] => @migrator.migrate(rest)
    ["conversations"] => @conversation.list()
    ["conversation", .. rest] => @conversation.show(rest)
    [.. rest] => @interactive.interactive(rest)
  }
}
