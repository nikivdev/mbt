///|
priv suberror HttpError {
  HttpError(code~ : Int, body~ : String)
} derive(Show, ToJson)

///|
/// Execute a chat completion request with the OpenAI API.
///
/// Sends a chat completion request to the model's endpoint and returns the parsed response.
/// Includes automatic retry logic with exponential backoff for transient failures.
///
/// Parameters:
/// - model: The model configuration containing API credentials and endpoint
/// - request: The chat completion parameters including messages, tools, and settings
///
/// Returns a ChatCompletion object containing the model's response, including generated
/// messages, token usage, and metadata.
///
/// Raises HttpError if the API returns a non-2xx status code.
pub async fn chat(
  model~ : @model.Model,
  request : ChatCompletionParam,
  logger? : @pino.Logger = @pino.logger("openai", @pino.Transport::sink()),
) -> ChatCompletion {
  @async.retry(
    ExponentialDelay(initial=1000, factor=2.0, maximum=16000),
    max_retry=5,
    () => {
      logger.debug("RequestSent", {
        "model": { "name": model.model_name, "base_url": model.base_url },
        "request": request.to_json(),
      })
      let url = "\{model.base_url}/chat/completions"
      let uri = Uri::parse(url)
      let client = @http.Client::connect(uri.host, protocol=uri.protocol, headers={
        "Authorization": "Bearer \{model.api_key}",
        "Content-Type": "application/json",
        "Connection": "close",
      })
      defer client.close()
      let response = client.post(uri.path, request.to_json())
      guard response.code is (200..=299) else {
        raise HttpError(code=response.code, body=client.read_all().text())
      }
      if request.stream is Some(true) {
        let reader = ChunkReader::new(client)
        let builder = ChatCompletionBuilder::new()
        while reader.read() is Some(chunk) {
          logger.debug("ChunkReceived", { "chunk": chunk.to_json() })
          builder.add_chunk(chunk)
        }
        let chat_completion = builder.to_chat_completion()
        logger.debug("ResponseReceived", {
          "model": { "name": model.model_name, "base_url": model.base_url },
          "response_code": response.code.to_json(),
          "response_body": chat_completion.to_json(),
        })
        chat_completion
      } else {
        let body = client.read_all().text()
        let json = @json.parse(body)
        let chat_completion : ChatCompletion = @json.from_json(json)
        logger.debug("ResponseReceived", {
          "model": { "name": model.model_name, "base_url": model.base_url },
          "response_code": response.code.to_json(),
          "response_body": chat_completion.to_json(),
        })
        chat_completion
      }
    },
  )
}

///|
priv struct ChunkReader(&@io.Reader)

///|
fn ChunkReader::new(reader : &@io.Reader) -> ChunkReader {
  ChunkReader(reader)
}

///|
async fn ChunkReader::read(self : ChunkReader) -> ChatCompletionChunk? {
  for {
    guard self.0.read_until("\n") is Some(line) else { return None }
    guard line is [.. "data: ", .. rest] else { continue }
    if rest.trim_space() == "[DONE]" {
      return None
    }
    let json = @json.parse(rest)
    let chunk : ChatCompletionChunk = @json.from_json(json)
    return Some(chunk)
  }
}

///|
/// Generate a simple text response from a prompt.
///
/// Convenience function that sends a single user prompt to the model and returns
/// the text content of the response. Automatically handles the system message and
/// extraction of the response content.
///
/// Parameters:
/// - model: The model configuration containing API credentials and endpoint
/// - prompt: The user's prompt text
///
/// Returns the text content of the model's response.
/// Fails if the completion has no content in the message.
pub async fn text(model~ : @model.Model, prompt~ : String) -> String {
  let completion = chat(
    model~,
    chat_completion(
      model=model.model_name,
      messages=[
        system_message(content="You are a helpful assistant."),
        user_message(content=prompt),
      ],
      max_tokens=150,
      temperature=0.7,
    ),
  )
  guard completion.choices[0].message.content is Some(content) else {
    fail("No content in completion message")
  }
  content
}

///|
fn extract_first_json_block(content : String) -> String? {
  content
  .split("```json")
  .drop(1)
  .take(1)
  .peek()
  .bind(block => block
    .split("```")
    .take(1)
    .peek()
    .map(s => s.trim(char_set=" \r\n\t").to_string()))
}

///|
test "extract_first_json_block" {
  let content =
    #|Here is some text.
    #|```json
    #|{
    #|  "key": "value"
    #|}
    #|```
    #|Some more text.
    #|```json
    #|{
    #|  "another_key": "another_value"
    #|}
    #|```
  @json.inspect(extract_first_json_block(content), content=[
    "{\n  \"key\": \"value\"\n}",
  ])
}

///|
/// Generate a JSON response from a prompt.
///
/// Requests the model to return a JSON object in a code block (wrapped in ```json```)
/// and extracts the first JSON block from the response.
///
/// Parameters:
/// - model: The model configuration containing API credentials and endpoint
/// - prompt: The user's prompt text requesting JSON output
///
/// Returns a parsed Json object from the model's response.
///
/// Fails if the completion has no content, no JSON code block is found in the response,
/// or the JSON cannot be parsed.
pub async fn json(model~ : @model.Model, prompt~ : String) -> Json {
  let completion = chat(
    model~,
    chat_completion(
      model=model.model_name,
      messages=[
        system_message(content="You are a helpful assistant."),
        user_message(content=prompt),
      ],
      max_tokens=150,
      temperature=0.7,
    ),
  )
  guard completion.choices[0].message.content is Some(content) else {
    fail("No content in completion message")
  }
  guard extract_first_json_block(content) is Some(content) else {
    fail("No JSON block found in completion message")
  }
  content |> @json.parse()
}

///|
/// Trait for types that can be automatically generated from structured prompts.
///
/// Types implementing this trait can describe themselves with a name, description,
/// and JSON schema, allowing the model to generate responses that conform to
/// the expected structure.
pub(open) trait Structural: @json.FromJson {
  name() -> String
  description() -> String
  schema() -> @schema.Schema
}

///|
/// Generate structured data from a prompt using JSON schema.
///
/// This function uses the model's JSON schema support to ensure the response
/// conforms to a specific structure defined by the type parameter `T`. The
/// response is automatically parsed and validated against the schema.
///
/// # Type Parameters
/// - `T`: A type implementing `Structural` trait that defines the expected schema
///
/// # Parameters
/// - `model`: The model configuration containing API credentials and endpoint
/// - `prompt`: The user's prompt text
///
/// # Returns
/// A value of type `T` parsed from the model's structured response
///
/// Fails if the completion has no content, the JSON cannot be parsed,
/// or the parsed JSON doesn't match the expected schema.
pub async fn[T : Structural] data(model~ : @model.Model, prompt~ : String) -> T {
  let completion = chat(
    model~,
    chat_completion(
      model=model.model_name,
      messages=[
        system_message(content="You are a helpful assistant."),
        user_message(content=prompt),
      ],
      max_tokens=150,
      temperature=0.7,
      response_format=json_schema(
        name=T::name(),
        schema=T::schema().to_json(),
        description=T::description(),
      ),
    ),
  )
  guard completion.choices[0].message.content is Some(content) else {
    fail("No content in completion message")
  }
  content |> @json.parse() |> @json.from_json()
}
