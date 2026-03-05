require "../src/fm"

# Direct JSON schema usage without Generable

model = Fm::SystemLanguageModel.new
model.ensure_available!

session = Fm::Session.new(model)

# Define a schema manually
schema = <<-JSON
{
  "type": "object",
  "properties": {
    "title": { "type": "string" },
    "rating": { "type": "integer" },
    "tags": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "required": ["title", "rating", "tags"]
}
JSON

json_str = session.respond_json("Generate a movie review for a sci-fi film.", schema)
parsed = JSON.parse(json_str)

puts "Title: #{parsed["title"]}"
puts "Rating: #{parsed["rating"]}"
puts "Tags: #{parsed["tags"].as_a.join(", ")}"
