///|
async test "timeout" (t : @test.Test) {
  @mock.run(t, mock => @async.with_task_group(_ => {
    let tool = @execute_command.new(@job.Manager::new(cwd=mock.cwd.path()))
    @json.inspect(tool.call({ "command": "sleep 5", "timeout": 1000 }), content=[
      "Ok",
      [
        "TimedOut",
        {
          "command": "sleep 5",
          "timeout": 1000,
          "stdout": "",
          "stderr": "",
          "max_output_lines": 100,
        },
      ],
    ])
  }))
}

///|
async test "cat" (t : @test.Test) {
  @mock.run(t, taco => {
    let _ = taco.add_file("file.txt", content="hello world")
    let tool = @execute_command.new(@job.Manager::new(cwd=taco.cwd.path()))
    let result = tool.call({ "command": "cat file.txt", "timeout": 5000 })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output,
      content=(
        #|Command cat file.txt exited with status 0.
        #|=== STDOUT (1 lines) ===
        #|hello world
        #|=== STDERR (1 lines) ===
        #|
      ),
    )
  })
}

///|
async test "output-overflow" (t : @test.Test) {
  @mock.run(t, taco => {
    let lines = []
    for i = 0; i < 100; i = i + 1 {
      lines.push("hello")
    }
    let _ = taco.add_file("file.txt", content=lines.join("\n"))
    let tool = @execute_command.new(@job.Manager::new(cwd=taco.cwd.path()))
    let result = tool.call({
      "command": "cat file.txt",
      "timeout": 5000,
      "max_output_lines": 5,
    })
    // For output-overflow case, we can't predict the exact UUID in the output_file path
    // So we'll check the structure and key fields, allowing flexibility for the UUID
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output,
      content=(
        #|Command cat file.txt exited with status 0.
        #|=== STDOUT (first 5 of 100 lines) ===
        #|hello
        #|hello
        #|hello
        #|hello
        #|hello
        #|... (truncated, try using redirection to pipe output to a file) ...
        #|=== STDERR (1 lines) ===
        #|
      ),
    )
  })
}

///|
async test "cd" (t : @test.Test) {
  @mock.run(t, taco => {
    let _ = taco.add_file("file.txt", content="hello world")
    let tool = @execute_command.new(@job.Manager::new(cwd=taco.cwd.path()))
    let result = tool.call({ "command": "cat file.txt", "timeout": 5000 })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(output, content=[
      "Completed",
      {
        "command": "cat file.txt",
        "status": 0,
        "stdout": "hello world",
        "stderr": "",
        "max_output_lines": 100,
      },
    ])
    let _ = taco
      .add_directory("subdir")
      .add_file("file.txt", content="hello from subdir")
    let tool = @execute_command.new(@job.Manager::new(cwd=taco.cwd.path()))
    let result = tool.call({
      "command": "cd subdir && cat file.txt",
      "timeout": 5000,
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(output, content=[
      "Completed",
      {
        "command": "cd subdir && cat file.txt",
        "status": 0,
        "stdout": "hello from subdir",
        "stderr": "",
        "max_output_lines": 100,
      },
    ])
  })
}

///|
async test "background" (t : @test.Test) {
  @mock.run(t, taco => {
    let manager = @job.Manager::new(cwd=taco.cwd.path())
    taco.group.spawn_bg(() => manager.start(), no_wait=true)
    let tool = @execute_command.new(manager)
    let result = tool.call({ "command": "sleep 2", "background": true })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(output, content=[
      "Background",
      { "command": "sleep 2", "job_id": 0 },
    ])
  })
}
