///|
async test "todo_write/create/plain" (t : @test.Test) {
  @mock.run(t, taco => {
    let todo_list = @todo.new(
      clock=taco.clock,
      uuid=taco.uuid,
      cwd=taco.cwd.path(),
    )
    let result = @todo_write.new(todo_list).call({
      "action": "create",
      "content": (
        #|Test todo item
        #|Another test item
      ),
      "priority": "high",
    })
    @json.inspect(result, content=[
      "Ok",
      {
        "todos": [
          {
            "content": "Test todo item",
            "created_at": "Tick:3",
            "id": "ac8a366d",
            "priority": "High",
            "status": "Pending",
            "updated_at": "Tick:3",
          },
          {
            "content": "Another test item",
            "created_at": "Tick:4",
            "id": "1ea1417c",
            "priority": "High",
            "status": "Pending",
            "updated_at": "Tick:4",
          },
        ],
        "message": "Created 2 new todo items",
        "updated_todos": [
          {
            "content": "Test todo item",
            "created_at": "Tick:3",
            "id": "ac8a366d",
            "priority": "High",
            "status": "Pending",
            "updated_at": "Tick:3",
          },
          {
            "content": "Another test item",
            "created_at": "Tick:4",
            "id": "1ea1417c",
            "priority": "High",
            "status": "Pending",
            "updated_at": "Tick:4",
          },
        ],
        "is_new_creation": true,
      },
    ])
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output,
      content=(
        #|✅ Operation completed: Created 2 new todo items
        #|
        #|📝 Newly created todos:
        #|  🔴 ⏳ [ac8a366d] Test todo item
        #|  🔴 ⏳ [1ea1417c] Another test item
        #|
        #|📊 Current summary: Total 2 items | Pending 2 | In Progress 0 | Completed 0
      ),
    )
  })
}

///|
async test "todo_write/create/<task>" (t : @test.Test) {
  @mock.run(t, taco => {
    let todo_list = @todo.new(
      clock=taco.clock,
      uuid=taco.uuid,
      cwd=taco.cwd.path(),
    )
    let result = @todo_write.new(todo_list).call({
      "action": "create",
      "content": (
        #|<task>Examine reference repository structure at .moonagent/repos/ini</task>
        #|<task>Examine current MoonBit project structure</task>
        #|<task>Analyze source files in ini repository</task>
        #|<task>Plan migration strategy preserving original structure</task>
        #|<task>Translate C/C++ files to MoonBit file-by-file</task>
        #|<task>Create appropriate MoonBit module structure</task>
        #|<task>Test migrated functionality</task>
      ),
    })
    @json.inspect(result, content=[
      "Ok",
      {
        "todos": [
          {
            "content": "Examine reference repository structure at .moonagent/repos/ini",
            "created_at": "Tick:3",
            "id": "ac8a366d",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:3",
          },
          {
            "content": "Examine current MoonBit project structure",
            "created_at": "Tick:4",
            "id": "1ea1417c",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:4",
          },
          {
            "content": "Analyze source files in ini repository",
            "created_at": "Tick:5",
            "id": "f378dd8d",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:5",
          },
          {
            "content": "Plan migration strategy preserving original structure",
            "created_at": "Tick:6",
            "id": "42858c8d",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:6",
          },
          {
            "content": "Translate C/C++ files to MoonBit file-by-file",
            "created_at": "Tick:7",
            "id": "1258fdc0",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:7",
          },
          {
            "content": "Create appropriate MoonBit module structure",
            "created_at": "Tick:8",
            "id": "aaa2f959",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:8",
          },
          {
            "content": "Test migrated functionality",
            "created_at": "Tick:9",
            "id": "8f0ff2dc",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:9",
          },
        ],
        "message": "Created 7 new todo items",
        "updated_todos": [
          {
            "content": "Examine reference repository structure at .moonagent/repos/ini",
            "created_at": "Tick:3",
            "id": "ac8a366d",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:3",
          },
          {
            "content": "Examine current MoonBit project structure",
            "created_at": "Tick:4",
            "id": "1ea1417c",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:4",
          },
          {
            "content": "Analyze source files in ini repository",
            "created_at": "Tick:5",
            "id": "f378dd8d",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:5",
          },
          {
            "content": "Plan migration strategy preserving original structure",
            "created_at": "Tick:6",
            "id": "42858c8d",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:6",
          },
          {
            "content": "Translate C/C++ files to MoonBit file-by-file",
            "created_at": "Tick:7",
            "id": "1258fdc0",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:7",
          },
          {
            "content": "Create appropriate MoonBit module structure",
            "created_at": "Tick:8",
            "id": "aaa2f959",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:8",
          },
          {
            "content": "Test migrated functionality",
            "created_at": "Tick:9",
            "id": "8f0ff2dc",
            "priority": "Medium",
            "status": "Pending",
            "updated_at": "Tick:9",
          },
        ],
        "is_new_creation": true,
      },
    ])
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output,
      content=(
        #|✅ Operation completed: Created 7 new todo items
        #|
        #|📝 Newly created todos:
        #|  🟡 ⏳ [ac8a366d] Examine reference repository structure at .moonagent/repos/ini
        #|  🟡 ⏳ [1ea1417c] Examine current MoonBit project structure
        #|  🟡 ⏳ [f378dd8d] Analyze source files in ini repository
        #|  🟡 ⏳ [42858c8d] Plan migration strategy preserving original structure
        #|  🟡 ⏳ [1258fdc0] Translate C/C++ files to MoonBit file-by-file
        #|  🟡 ⏳ [aaa2f959] Create appropriate MoonBit module structure
        #|  🟡 ⏳ [8f0ff2dc] Test migrated functionality
        #|
        #|📊 Current summary: Total 7 items | Pending 7 | In Progress 0 | Completed 0
      ),
    )
  })
}

///|
async test "todo_write/update" (t : @test.Test) {
  @mock.run(t, taco => {
    let todo_list = @todo.new(
      clock=taco.clock,
      uuid=taco.uuid,
      cwd=taco.cwd.path(),
    )
    let result = @todo_write.new(todo_list).call({
      "action": "create",
      "content": (
        #|First item
        #|Second item
      ),
      "priority": "medium",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output,
      content=(
        #|✅ Operation completed: Created 2 new todo items
        #|
        #|📝 Newly created todos:
        #|  🟡 ⏳ [ac8a366d] First item
        #|  🟡 ⏳ [1ea1417c] Second item
        #|
        #|📊 Current summary: Total 2 items | Pending 2 | In Progress 0 | Completed 0
      ),
    )
    let result = @todo_write.new(todo_list).call({
      "action": "update",
      "task_id": "ac8a366d",
      "status": "in-progress",
      "priority": "high",
      "content": "Updated first item",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output,
      content=(
        #|✅ Operation completed: Updated task: Updated first item
        #|
        #|📝 Current todo list:
        #|  🔴 🔄 [ac8a366d] Updated first item
        #|  🟡 ⏳ [1ea1417c] Second item
        #|
        #|✨ Updated items:
        #|  🔴 🔄 [ac8a366d] Updated first item
        #|
        #|📊 Current summary: Total 2 items | Pending 1 | In Progress 1 | Completed 0
      ),
    )
  })
}

///|
async test "todo_write/mark_completed" (t : @test.Test) {
  @mock.run(t, taco => {
    let todo_list = @todo.new(
      clock=taco.clock,
      uuid=taco.uuid,
      cwd=taco.cwd.path(),
    )
    let result = @todo_write.new(todo_list).call({
      "action": "create",
      "content": (
        #|First item
        #|Second item
      ),
      "priority": "medium",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output,
      content=(
        #|✅ Operation completed: Created 2 new todo items
        #|
        #|📝 Newly created todos:
        #|  🟡 ⏳ [ac8a366d] First item
        #|  🟡 ⏳ [1ea1417c] Second item
        #|
        #|📊 Current summary: Total 2 items | Pending 2 | In Progress 0 | Completed 0
      ),
    )
    let result = @todo_write.new(todo_list).call({
      "action": "mark_completed",
      "task_id": "nonexistent",
    })
    @json.inspect(result, content=[
      "Error",
      ["ToolFailure", "Error: Task with ID 'nonexistent' not found."],
      "Error: Task with ID 'nonexistent' not found.",
    ])
    let result = @todo_write.new(todo_list).call({
      "action": "mark_completed",
      "task_id": "ac8a366d",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output,
      content=(
        #|✅ Operation completed: Marked task as completed: First item
        #|
        #|📝 Current todo list:
        #|  🟡 ✅ [ac8a366d] First item
        #|  🟡 ⏳ [1ea1417c] Second item
        #|
        #|✨ Updated items:
        #|  🟡 ✅ [ac8a366d] First item
        #|
        #|📊 Current summary: Total 2 items | Pending 1 | In Progress 0 | Completed 1
      ),
    )
  })
}

///|
async test "todo_write/mark_progress" (t : @test.Test) {
  @mock.run(t, taco => {
    let todo_list = @todo.new(
      clock=taco.clock,
      uuid=taco.uuid,
      cwd=taco.cwd.path(),
    )
    let result = @todo_write.new(todo_list).call({
      "action": "create",
      "content": (
        #|First item
        #|Second item
      ),
      "priority": "medium",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output,
      content=(
        #|✅ Operation completed: Created 2 new todo items
        #|
        #|📝 Newly created todos:
        #|  🟡 ⏳ [ac8a366d] First item
        #|  🟡 ⏳ [1ea1417c] Second item
        #|
        #|📊 Current summary: Total 2 items | Pending 2 | In Progress 0 | Completed 0
      ),
    )
    let result = @todo_write.new(todo_list).call({
      "action": "mark_progress",
      "task_id": "nonexistent",
    })
    @json.inspect(result, content=[
      "Error",
      ["ToolFailure", "Error: Task with ID 'nonexistent' not found."],
      "Error: Task with ID 'nonexistent' not found.",
    ])
    inspect(result, content="Error: Task with ID 'nonexistent' not found.")
    let result = @todo_write.new(todo_list).call({
      "action": "mark_progress",
      "task_id": "ac8a366d",
    })
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    inspect(
      output,
      content=(
        #|✅ Operation completed: Marked task as in progress: First item
        #|
        #|📝 Current todo list:
        #|  🟡 🔄 [ac8a366d] First item
        #|  🟡 ⏳ [1ea1417c] Second item
        #|
        #|✨ Updated items:
        #|  🟡 🔄 [ac8a366d] First item
        #|
        #|📊 Current summary: Total 2 items | Pending 1 | In Progress 1 | Completed 0
      ),
    )
  })
}
