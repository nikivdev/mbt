///|
async test "load" (t : @test.Test) {
  @mock.run(t, mock => {
    let home = mock.cwd
    let home_models : Json = [
      {
        "name": "anthropic/claude-sonnet-4",
        "description": "claude sonnet model for general tasks",
        "model_name": "anthropic/claude-sonnet-4",
        "model_type": "saas/openai",
        "base_url": "https://openrouter.ai/api/v1",
        "is_reasoning": false,
        "input_price": 21.0,
        "output_price": 105.0,
        "average_speed": 0,
        "safe_zone_tokens": 128000,
        "max_output_tokens": 24288,
        "api_key": "sk-test",
        "supports_anthropic_prompt_caching": true,
      },
      {
        "name": "qwen/qwen3-coder",
        "description": "qwen coder",
        "model_name": "qwen/qwen3-coder",
        "model_type": "saas/openai",
        "base_url": "https://openrouter.ai/api/v1",
        "is_reasoning": false,
        "input_price": 21.0,
        "output_price": 105.0,
        "average_speed": 0,
        "safe_zone_tokens": 256000,
        "max_output_tokens": 24288,
        "api_key": "sk-test",
      },
      {
        "name": "google/gemini-2.5-pro",
        "description": "google gemini 2.5 pro for translate or long-context complex task",
        "model_name": "google/gemini-2.5-pro",
        "model_type": "saas/openai",
        "base_url": "https://openrouter.ai/api/v1",
        "is_reasoning": false,
        "input_price": 21.0,
        "output_price": 105.0,
        "average_speed": 0,
        "safe_zone_tokens": 1000000,
        "max_output_tokens": 24288,
        "api_key": "sk-test",
      },
    ]
    let _ = home
      .add_directory(".moonagent")
      .add_directory("models")
      .add_file(
        "models.json",
        content=home_models.to_json().stringify(indent=2),
      )
    let project = home.add_directory("project")
    let project_models : Json = [
      {
        "name": "google/gemini-2.5-flash",
        "description": "google gemini 2.5 flash for long-context simple task",
        "model_name": "google/gemini-2.5-flash",
        "model_type": "saas/openai",
        "base_url": "https://openrouter.ai/api/v1",
        "is_reasoning": false,
        "input_price": 21.0,
        "output_price": 105.0,
        "average_speed": 0,
        "safe_zone_tokens": 1000000,
        "max_output_tokens": 24288,
        "api_key": "sk-test",
        "supports_anthropic_prompt_caching": true,
      },
      {
        "name": "deepseek/deepseek-chat-v3.1",
        "description": "deepseek chat v3.1 for general tasks",
        "model_name": "deepseek-chat",
        "model_type": "saas/openai",
        "base_url": "https://api.deepseek.com",
        "is_reasoning": false,
        "safe_zone_tokens": 131000,
        "max_output_tokens": 8192,
        "api_key": "sk-test",
      },
    ]
    let _ = project
      .add_directory(".moonagent")
      .add_directory("models")
      .add_file(
        "models.json",
        content=project_models.to_json().stringify(indent=2),
      )
    let loader = Loader::new(
      home=home.path(),
      cwd=project.path(),
      logger=mock.logger,
    )
    @json.inspect(mock.json(loader.get_model()), content=[
      {
        "name": "google/gemini-2.5-flash",
        "description": "google gemini 2.5 flash for long-context simple task",
        "model_name": "google/gemini-2.5-flash",
        "model_type": "saas/openai",
        "api_key": "(mock:env:OPENAI_API_KEY)",
        "base_url": "https://openrouter.ai/api/v1",
        "safe_zone_tokens": 1000000,
        "supports_anthropic_prompt_caching": true,
      },
    ])
    @json.inspect(
      mock.json(loader.get_model(name="anthropic/claude-sonnet-4")),
      content=[
        {
          "name": "anthropic/claude-sonnet-4",
          "description": "claude sonnet model for general tasks",
          "model_name": "anthropic/claude-sonnet-4",
          "model_type": "saas/openai",
          "api_key": "(mock:env:OPENAI_API_KEY)",
          "base_url": "https://openrouter.ai/api/v1",
          "safe_zone_tokens": 128000,
          "supports_anthropic_prompt_caching": true,
        },
      ],
    )
    @json.inspect(mock.json(loader.get_model(name="qwen/qwen3-coder")), content=[
      {
        "name": "qwen/qwen3-coder",
        "description": "qwen coder",
        "model_name": "qwen/qwen3-coder",
        "model_type": "saas/openai",
        "api_key": "(mock:env:OPENAI_API_KEY)",
        "base_url": "https://openrouter.ai/api/v1",
        "safe_zone_tokens": 256000,
        "supports_anthropic_prompt_caching": false,
      },
    ])
  })
}
