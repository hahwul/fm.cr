require "../src/fm"

# DEPRECATED (since fm.cr v0.3.0)
# `AdapterAsset` was removed in the macOS 26.2 SDK, so `Fm::Adapter` no longer
# loads on macOS 26.2+. This example is kept for reference only — see
# CHANGELOG.md and prefer `examples/basic.cr` / `examples/structured.cr` on
# current macOS versions.

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
