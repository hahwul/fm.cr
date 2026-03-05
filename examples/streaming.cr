require "../src/fm"

# Streaming response example

model = Fm::SystemLanguageModel.new
model.ensure_available!

session = Fm::Session.new(model, instructions: "You are a creative storyteller.")

options = Fm::GenerationOptions.new(temperature: 0.8)

print "Story: "
session.stream("Tell me a very short story about a robot.", options) do |chunk|
  print chunk
  STDOUT.flush
end
puts
