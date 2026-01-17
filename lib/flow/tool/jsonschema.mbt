///|
pub(all) struct JsonSchema(Json)

///|
pub fn JsonSchema::from_json(schema : Json) -> JsonSchema {
  JsonSchema(schema)
}

///|
pub impl ToJson for JsonSchema with to_json(self : JsonSchema) -> Json {
  let JsonSchema(schema) = self
  schema
}
