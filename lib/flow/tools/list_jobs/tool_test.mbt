///|
async test "list_jobs" (t : @test.Test) {
  @mock.run(t, mock => {
    let manager = @job.Manager::new(cwd=mock.cwd.path())
    mock.group.spawn_bg(() => manager.start(), no_wait=true)
    let tool = @list_jobs.new(manager)
    let _ = manager.spawn(name="sleep", command="sleep 2")
    let result = tool.call({})
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      mock.show(output),
      content=(
        #|- [0] sleep
        #|  Command: sleep 2
        #|  CWD: (mock:cwd)
        #|  Stdout: (mock:cwd)/.moonagent/jobs/0/stdout
        #|  Stderr: (mock:cwd)/.moonagent/jobs/0/stderr
        #|  Status: Running
        #|
      ),
    )
  })
}

///|
async test "list_jobs/multiple" (t : @test.Test) {
  @mock.run(t, mock => {
    let manager = @job.Manager::new(cwd=mock.cwd.path())
    mock.group.spawn_bg(() => manager.start(), no_wait=true)
    let tool = @list_jobs.new(manager)
    let _ = manager.spawn(name="job1", command="sleep 1 && echo job1")
    let _ = manager.spawn(name="job2", command="sleep 1 && echo job2")
    let result = tool.call({})
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      mock.show(output),
      content=(
        #|- [0] job1
        #|  Command: sleep 1 && echo job1
        #|  CWD: (mock:cwd)
        #|  Stdout: (mock:cwd)/.moonagent/jobs/0/stdout
        #|  Stderr: (mock:cwd)/.moonagent/jobs/0/stderr
        #|  Status: Running
        #|- [1] job2
        #|  Command: sleep 1 && echo job2
        #|  CWD: (mock:cwd)
        #|  Stdout: (mock:cwd)/.moonagent/jobs/1/stdout
        #|  Stderr: (mock:cwd)/.moonagent/jobs/1/stderr
        #|  Status: Running
        #|
      ),
    )
  })
}

///|
async test "list_jobs/completed" (t : @test.Test) {
  @mock.run(t, mock => {
    let manager = @job.Manager::new(cwd=mock.cwd.path())
    mock.group.spawn_bg(() => manager.start(), no_wait=true)
    let tool = @list_jobs.new(manager)
    let _ = manager.spawn(name="job1", command="sleep 1 && echo job1")
    let _ = manager.spawn(name="job2", command="sleep 1 && echo job2")
    @async.sleep(2_000)
    let result = tool.call({})
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      mock.show(output),
      content=(
        #|- [0] job1
        #|  Command: sleep 1 && echo job1
        #|  CWD: (mock:cwd)
        #|  Stdout: (mock:cwd)/.moonagent/jobs/0/stdout
        #|  Stderr: (mock:cwd)/.moonagent/jobs/0/stderr
        #|  Status: Completed (exit code: 0)
        #|- [1] job2
        #|  Command: sleep 1 && echo job2
        #|  CWD: (mock:cwd)
        #|  Stdout: (mock:cwd)/.moonagent/jobs/1/stdout
        #|  Stderr: (mock:cwd)/.moonagent/jobs/1/stderr
        #|  Status: Completed (exit code: 0)
        #|
      ),
    )
  })
}
