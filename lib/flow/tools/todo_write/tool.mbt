///|
struct TodoWriteResult {
  todos : Array[@todo.Item]
  message : String
  updated_todos : Array[@todo.Item]
  is_new_creation : Bool
} derive(ToJson, @json.FromJson)

///|
pub impl Show for TodoWriteResult with output(
  self : TodoWriteResult,
  logger : &Logger,
) -> Unit {
  let todos = self.todos
  let action_performed = self.message
  let updated_todos = self.updated_todos
  let is_new_creation = self.is_new_creation
  let output = []
  output.push("✅ Operation completed: \{action_performed}\n")

  // Show newly created todos specifically for create action
  if is_new_creation {
    if updated_todos.length() > 0 {
      output.push("📝 Newly created todos:")
      for todo in updated_todos {
        let priority_icon = todo.priority.icon()
        let status_icon = todo.status.icon()
        output.push(
          "  \{priority_icon} \{status_icon} [\{todo.id}] \{todo.content}",
        )
      }
    }
  } else {
    // Always show all todos
    output.push("📝 Current todo list:")
    for todo in todos {
      let priority_icon = todo.priority.icon()
      let status_icon = todo.status.icon()
      output.push(
        "  \{priority_icon} \{status_icon} [\{todo.id}] \{todo.content}",
      )
    }

    // Highlight updated todos if provided
    if updated_todos.length() > 0 {
      output.push("\n✨ Updated items:")
      for todo in updated_todos {
        let priority_icon = todo.priority.icon()
        let status_icon = todo.status.icon()
        output.push(
          "  \{priority_icon} \{status_icon} [\{todo.id}] \{todo.content}",
        )
      }
    }
  }
  let total_todos = todos.length()
  let mut pending_count = 0
  let mut in_progress_count = 0
  let mut completed_count = 0
  for todo in todos {
    match todo.status {
      Pending => pending_count = pending_count + 1
      InProgress => in_progress_count = in_progress_count + 1
      Completed => completed_count = completed_count + 1
    }
  }
  output.push(
    "\n📊 Current summary: Total \{total_todos} items | Pending \{pending_count} | In Progress \{in_progress_count} | Completed \{completed_count}",
  )
  logger.write_string(output.join("\n"))
}

///|
async fn @todo.Todo::execute_todo_write(
  self : @todo.Todo,
  args : Json,
) -> @tool.ToolResult[TodoWriteResult] noraise {
  enum Action {
    Create
    AddTask
    Update
    MarkProgress
    MarkCompleted
  }
  // Parse required action parameter
  guard args is { "action": String(action), .. } else {
    return @tool.error("Error: 'action' parameter is required")
  }
  let action = action.to_lower()
  let action = match action {
    "create" => Create
    "add_task" => AddTask
    "update" => Update
    "mark_progress" => MarkProgress
    "mark_completed" => MarkCompleted
    _ =>
      return @tool.error(
        "Error: Invalid action '\{action}'. Supported actions: create, add_task, update, mark_progress, mark_completed.",
      )
  }

  // Parse optional parameters
  let content : String? = match args {
    { "content": String(c), .. } => Some(c)
    _ => None
  }
  let task_id : String? = match args {
    { "task_id": String(t), .. } => Some(t)
    _ => None
  }
  let priority : @todo.Priority = match args {
    { "priority": p, .. } =>
      match p {
        "high" => High
        "medium" => Medium
        "low" => Low
        _ =>
          return @tool.error(
            "Error: Invalid priority '\{p}'. Must be 'high', 'medium', or 'low'.",
          )
      }
    _ => Medium
  }
  let status : @todo.Status = match args {
    { "status": s, .. } =>
      match s {
        "pending" => Pending
        "in_progress" | "in-progress" => InProgress
        "completed" => Completed
        _ =>
          return @tool.error(
            "Error: Invalid status '\{s}'. Must be 'pending', 'in_progress', or 'completed'.",
          )
      }
    _ => Pending
  }
  let notes : String? = match args {
    { "notes": String(n), .. } => Some(n)
    _ => None
  }
  self.load() catch {
    error =>
      return @tool.error("Error loading existing todo list: \{error}", error~)
  }
  match action {
    Create =>
      match content {
        None =>
          return @tool.error("Error: Content is required for creating todos.")
        Some(content) => {
          // Clear existing todos and create new ones
          self.parse(content, priority~, notes?)
          try {
            self.save()
            let todos = self.todos()
            return @tool.ok({
              todos,
              message: "Created \{todos.length()} new todo items",
              updated_todos: todos,
              is_new_creation: true,
            })
          } catch {
            error =>
              return @tool.error("Failed to save todo list: \{error}", error~)
          }
        }
      }
    AddTask => {
      guard content is Some(content) else {
        return @tool.error("Error: Content is required for adding a task.")
      }
      let item = self.add_task(content, status~, priority~, notes~)
      try {
        self.save()
        return @tool.ok(TodoWriteResult::{
          todos: self.todos().map(t => t),
          message: "Added new task: \{item.content}",
          updated_todos: [item],
          is_new_creation: false,
        })
      } catch {
        error => return @tool.error("Failed to save new task: \{error}", error~)
      }
    }
    Update | MarkProgress | MarkCompleted => {
      guard task_id is Some(task_id) else {
        return @tool.error("Error: Task ID is required for update operations.")
      }
      guard self.find(task_id) is Some(task_index) else {
        return @tool.error("Error: Task with ID '\{task_id}' not found.")
      }
      let todo = self.get(task_index)
      // Apply specific action
      let updated_todos = []
      let action_message = match action {
        MarkProgress => {
          let updated_todo = todo.update(
            status=InProgress,
            updated_at=self.now(),
          )
          updated_todos.push(updated_todo)
          self.update_task(task_index, updated_todo)
          "Marked task as in progress: \{updated_todo.content}"
        }
        MarkCompleted => {
          let updated_todo = todo.update(
            status=Completed,
            updated_at=self.now(),
          )
          updated_todos.push(updated_todo)
          self.update_task(task_index, updated_todo)
          "Marked task as completed: \{updated_todo.content}"
        }
        Update => {
          let updated_todo = todo.update(
            content?,
            status~,
            priority~,
            notes~,
            updated_at=self.now(),
          )
          updated_todos.push(updated_todo)
          self.update_task(task_index, updated_todo)
          "Updated task: \{updated_todo.content}"
        }
        _ => abort("unreachable")
      }
      try {
        self.save()
        @tool.ok(TodoWriteResult::{
          todos: self.todos(),
          message: action_message,
          updated_todos,
          is_new_creation: false,
        })
      } catch {
        error =>
          return @tool.error("Failed to save task update: \{error}", error~)
      }
    }
  }
}

///|
let schema : @tool.JsonSchema = @tool.JsonSchema::from_json({
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "description": "The action to perform: 'create' (create new todo list), 'add_task' (add single task), 'update' (update existing task), 'mark_progress' (mark task as in progress), 'mark_completed' (mark task as completed)",
    },
    "content": {
      "type": "string",
      "description": "The task content or description (required for create, add_task actions). Can contain <task>...</task> tags for structured input.",
    },
    "task_id": {
      "type": "string",
      "description": "The ID of the task to update (required for update, mark_progress, mark_completed actions)",
    },
    "priority": {
      "type": "string",
      "description": "Task priority level: 'high', 'medium', 'low' (default: 'medium')",
    },
    "status": {
      "type": "string",
      "description": "Task status: 'pending', 'in_progress', 'completed' (default: 'pending')",
    },
    "notes": {
      "type": "string",
      "description": "Additional notes or details about the task",
    },
  },
  "required": ["action"],
})

///|
/// @param list the todolist is shared globally
pub fn new(list : @todo.Todo) -> @tool.Tool[TodoWriteResult] {
  @tool.new(
    description="Request to create and manage a structured task list for your current coding session. This helps you track progress, organize complex tasks, and demonstrate thoroughness to the user. It also helps the user understand the progress of the task and overall progress of their request. Use this tool proactively for complex multi-step tasks, when explicitly requested by the user, or when you need to organize multiple operations.",
    name="todo_write",
    schema~,
    async fn(args) -> @tool.ToolResult[TodoWriteResult] noraise {
      list.execute_todo_write(args)
    },
  )
}

///|
pub let prompt : String =
  #|# todo_write
  #|
  #|## Purpose
  #|
  #|- Create and manage structured task lists for complex coding sessions
  #|- Track progress on multi-step operations with status updates
  #|- Organize work into manageable, prioritized tasks
  #|- Provide clear progress visibility to users
  #|
  #|## When to Use
  #|
  #|Use this tool proactively in these scenarios, but ONLY AFTER thorough project exploration:
  #|
  #|- **FIRST EXPLORE THE PROJECT**: Always start with project exploration using
  #|  search_files, execute_command, and AC module searches
  #|- **Complex multi-step tasks**: When a task requires 3 or more distinct steps or
  #|  actions
  #|- **Non-trivial and complex tasks**: Tasks that require careful planning or
  #|  multiple operations
  #|- **User explicitly requests todo list**: When the user directly asks you to use
  #|  the todo list
  #|- **User provides multiple tasks**: When users provide a list of things to be
  #|  done (numbered or comma-separated)
  #|- **After receiving new instructions**: Immediately capture user requirements as
  #|  todos, but explore the codebase first
  #|- **When you start working on a task**: Mark it as in_progress BEFORE beginning
  #|  work (ideally only one task should be in_progress at a time)
  #|- **After completing a task**: Mark it as completed and add any new follow-up
  #|  tasks discovered during implementation
  #|
  #|## When NOT to Use
  #|
  #|Skip using this tool when:
  #|
  #|- There is only a **single, straightforward task**
  #|- The task is **trivial** and tracking it provides no organizational benefit
  #|- The task can be completed in **less than 3 trivial steps**
  #|- The task is **purely conversational or informational**
  #|
  #|**NOTE**: Do not use this tool if there is only one trivial task to do. In this
  #|case you are better off just doing the task directly.
  #|
  #|## Important Considerations
  #|
  #|- Each task gets a unique ID that can be used for future updates
  #|- Task content for 'create' action should be formatted as a numbered list for multiple tasks
  #|- The system automatically tracks task creation and modification timestamps
  #|- Todo lists persist across tool calls within the same session
  #|- Use descriptive task names that clearly indicate what needs to be accomplished
  #|
  #|## Example Usage Scenario
  #|
  #|```
  #|User: I want to add a dark mode toggle to the application settings. Make sure you run the tests and build when you're done!
  #|
  #|Assistant: I'll help add a dark mode toggle to your application settings. Let me create a todo list to track this implementation.
  #|
  #|Creates todo list with the following items:
  #|1. Create dark mode toggle component in Settings page
  #|2. Add dark mode state management (context/store)
  #|3. Implement CSS-in-JS styles for dark theme
  #|4. Update existing components to support theme switching
  #|5. Run tests and build process, addressing any failures or errors that occur
  #|
  #|Thinking: The assistant used the todo list because:
  #|1. Adding dark mode is a multi-step feature requiring UI, state management, and styling changes
  #|2. The user explicitly requested tests and build be run afterward
  #|3. The assistant inferred that tests and build need to pass by adding "Ensure tests and build succeed" as the final task
  #|```
  #|
  #|## Workflow Tips
  #|
  #|1. **Start with creation**: Use 'create' action to establish the initial task list for complex projects
  #|2. **Add tasks incrementally**: Use 'add_task' as new requirements emerge during implementation
  #|3. **Track progress actively**: Use 'mark_progress' when starting work on a task
  #|4. **Complete tasks promptly**: Use 'mark_completed' when tasks are finished
  #|5. **Add context**: Use 'notes' parameter to record important decisions or challenges
  #|6. **Review regularly**: Use todo_read to maintain awareness of overall progress
  #|
  #|By using these TODO tools effectively, you can maintain better organization, provide clear progress visibility, and demonstrate a systematic approach to complex coding tasks.
  #|
  #|IMPORTANT: BEFORE USING TODO TOOLS, ALWAYS CONDUCT THOROUGH PROJECT EXPLORATION FIRST!
  #|
  #|Begin every task by systematically exploring the project:
  #|
  #|1. Use search_files to understand the project structure and locate relevant files
  #|2. Use execute_command with grep patterns to find specific code patterns and implementations
  #|3. Search for existing AC modules that might provide functionality you can reuse
  #|
  #|Only after gathering sufficient information about the project structure, existing patterns, and available modules should you proceed to planning tasks with TODO tools.
  #|
  #|The TODO tools help you manage and track task progress during complex coding sessions. They provide structured task management capabilities that enhance productivity and demonstrate thoroughness to users.
  #|
