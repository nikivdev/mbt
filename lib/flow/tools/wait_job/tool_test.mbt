///|
async test "wait_job" (t : @test.Test) {
  @mock.run(t, mock => {
    let manager = @job.Manager::new(cwd=mock.cwd.path())
    mock.group.spawn_bg(() => manager.start(), no_wait=true)
    let tool = @wait_job.new(manager)
    let _ = manager.spawn(
      name="test_job",
      command="echo 'Hello, World!'; echo 'This is stderr' 1>&2; sleep 1",
    )
    let result = tool.call({
      "job_id": 0,
      "timeout": 5000,
      "max_output_lines": 2,
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      mock.show(output),
      content=(
        #|Job 0 completed with exit code 0
        #|Stdout ((mock:cwd)/.moonagent/jobs/0/stdout):
        #|Hello, World!
        #|
        #|Stderr:
        #|This is stderr
        #|
        #|
      ),
    )
  })
}
