require "../src/fm"

model = Fm::SystemLanguageModel.new
model.ensure_available!

# Load an adapter from a file path
adapter = Fm::Adapter.new(path: "/path/to/my-adapter.mlpackage")

# Create a session with the adapter
session = Fm::Session.new(model,
  instructions: "You are a helpful assistant.",
  adapters: [adapter]
)

response = session.respond("Hello!")
puts response.content
