///|
pub impl @json.FromJson for Model with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> Model {
  guard json is Object(json) else {
    raise @json.JsonDecodeError(
      (json_path, "@moonbitlang/maria/model.Model::from_json: expected object"),
    )
  }
  let name : String = {
    guard json.get("name") is Some(name) else {
      raise @json.JsonDecodeError(
        (
          json_path, "@moonbitlang/maria/model.Model::from_json: missing 'name' field",
        ),
      )
    }
    @json.from_json(name, path=json_path.add_key("name"))
  }
  let model_name : String = {
    guard json.get("model_name") is Some(model_name) else {
      raise @json.JsonDecodeError(
        (
          json_path, "@moonbitlang/maria/model.Model::from_json: missing 'model_name' field",
        ),
      )
    }
    @json.from_json(model_name, path=json_path.add_key("model_name"))
  }
  let model_type : Type = {
    guard json.get("model_type") is Some(model_type) else {
      raise @json.JsonDecodeError(
        (
          json_path, "@moonbitlang/maria/model.Model::from_json: missing 'model_type' field",
        ),
      )
    }
    @json.from_json(model_type, path=json_path.add_key("model_type"))
  }
  let api_key : String = {
    guard json.get("api_key") is Some(api_key) else { "" }
    @json.from_json(api_key, path=json_path.add_key("api_key"))
  }
  let base_url : String = {
    guard json.get("base_url") is Some(base_url) else {
      match model_type {
        SaaS(OpenAI) => "https://api.openai.com/v1"
      }
    }
    @json.from_json(base_url, path=json_path.add_key("base_url"))
  }
  let description : String? = {
    guard json.get("description") is Some(description) else { None }
    Some(@json.from_json(description, path=json_path.add_key("description")))
  }
  let safe_zone_tokens : Int = {
    guard json.get("safe_zone_tokens") is Some(safe_zone_tokens) else {
      // raise @json.JsonDecodeError(
      //   (
      //     json_path, "@moonbitlang/maria/model.Model::from_json: missing 'safe_zone_tokens' field",
      //   ),
      // )
      128_000
    }
    @json.from_json(
      safe_zone_tokens,
      path=json_path.add_key("safe_zone_tokens"),
    )
  }
  let supports_anthropic_prompt_caching : Bool = {
    guard json.get("supports_anthropic_prompt_caching")
      is Some(supports_anthropic_prompt_caching) else {
      false
    }
    @json.from_json(
      supports_anthropic_prompt_caching,
      path=json_path.add_key("supports_anthropic_prompt_caching"),
    )
  }
  Model::{
    name,
    description,
    model_name,
    model_type,
    api_key,
    base_url,
    safe_zone_tokens,
    supports_anthropic_prompt_caching,
  }
}

///|
pub impl @json.FromJson for Type with from_json(
  json : Json,
  json_path : @json.JsonPath,
) -> Type {
  guard json is String(json) else {
    raise @json.JsonDecodeError(
      (json_path, "@moonbitlang/maria/model.Type::from_json: expected string"),
    )
  }
  match json {
    "saas/openai" => Type::SaaS(Provider::OpenAI)
    [.. "saas/", .. provider] =>
      raise @json.JsonDecodeError(
        (
          json_path,
          "@moonbitlang/maria/model.Type::from_json: unsupported SaaS provider '\{provider}'",
        ),
      )
    _ =>
      raise @json.JsonDecodeError(
        (
          json_path,
          "@moonbitlang/maria/model.Type::from_json: unknown model type '\{json}'",
        ),
      )
  }
}

///|
pub impl ToJson for Type with to_json(self) {
  match self {
    SaaS(OpenAI) => "saas/openai"
  }
}
