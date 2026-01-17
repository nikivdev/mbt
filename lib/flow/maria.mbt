///|
pub struct Maria {
  logger : @pino.Logger
  agent : @agent.Agent
}

///|
pub suberror ModelNotConfigured

///|
#as_free_fn
pub async fn Maria::new(
  logger? : @pino.Logger = @pino.logger(
    "maria",
    try! @pino.transport("file:.moonagent/log.jsonl"),
  ),
  model? : String,
  cwd? : String,
) -> Maria {
  let home = @os.home()
  let cwd = match cwd {
    None => @os.cwd()
    Some(cwd) => cwd
  }
  let loader = @model.Loader::new(home~, cwd~, logger~)
  guard loader.get_model(name?=model) is Some(model) else {
    raise ModelNotConfigured
  }
  let agent = @agent.new(model, logger~, cwd~)
  let job_manager = @job.Manager::new(cwd=agent.cwd)
  let file_manager = @file.manager(cwd~)
  let todo_list = @todo.new(uuid=agent.uuid, cwd=agent.cwd)
  agent.add_tools([
    @execute_command.new(job_manager).to_agent_tool(),
    @list_files.new(file_manager).to_agent_tool(),
    @read_file.new(file_manager).to_agent_tool(),
    @todo_read.new(todo_list).to_agent_tool(),
    @todo_write.new(todo_list).to_agent_tool(),
    @search_files.new(agent.cwd).to_agent_tool(),
    @meta_write_to_file.new(agent).to_agent_tool(),
  ])
  let system_prompt = [
    @prompt.prelude, @prompt.moonbit, @todo_read.prompt, @todo_write.prompt, @search_files.prompt,
  ].join("\n")
  let system_message = @openai.system_message(content=system_prompt)
  agent.add_message(system_message)
  Maria::{ logger, agent }
}

///|
pub fn Maria::close(self : Maria) -> Unit {
  self.agent.close()
}

///|
pub async fn Maria::start(self : Maria, prompt : String) -> Unit {
  let user_message = @openai.user_message(content=prompt)
  self.agent.add_message(user_message)
  self.agent.start()
}
