///|
async test "maria/model-name" (t : @test.Test) {
  @mock.run(t, mock => {
    let api_key = mock.getenv("OPENAI_API_KEY")
    let model = @model.new(
      api_key~,
      base_url="https://openrouter.ai/api/v1",
      name="haiku",
      model_name="anthropic/claude-haiku-4.5",
      safe_zone_tokens=200000,
    )
    let models = [model]
    let models_file = mock.cwd
      .add_directory(".moonagent")
      .add_directory("models")
      .add_file("models.json")
    models_file.write_string(models.to_json().stringify(indent=2))
    @json.inspect(mock.json(@json.parse(models_file.read())), content=[
      {
        "name": "haiku",
        "model_name": "anthropic/claude-haiku-4.5",
        "model_type": "saas/openai",
        "api_key": "(mock:env:OPENAI_API_KEY)",
        "base_url": "https://openrouter.ai/api/v1",
        "safe_zone_tokens": 200000,
        "supports_anthropic_prompt_caching": false,
      },
    ])
    let maria = @maria.Maria::new(model="haiku", cwd=mock.cwd.path())
    // We don't snapshot anything here as we just expect to request to be
    // successful with loaded model name
    maria.start("Say 'Hello from loaded model' and nothing else.")
  })
}
