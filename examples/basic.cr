require "../src/fm"

# Basic usage of Apple FoundationModels via fm.cr

model = Fm::SystemLanguageModel.new

puts "Model available: #{model.available?}"
puts "Availability: #{model.availability}"

model.ensure_available!

session = Fm::Session.new(model, instructions: "You are a helpful assistant. Be concise.")

response = session.respond("What is the capital of France?")
puts "Response: #{response.content}"

# Multi-turn conversation
response = session.respond("And what about Germany?")
puts "Follow-up: #{response.content}"
