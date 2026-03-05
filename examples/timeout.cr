require "../src/fm"

# Timeout example: respond with a time limit

model = Fm::SystemLanguageModel.new
model.ensure_available!

session = Fm::Session.new(model, instructions: "You are a helpful assistant.")

begin
  response = session.respond("Explain quantum computing briefly.", timeout: 10.seconds)
  puts response.content
rescue ex : Fm::TimeoutError
  puts "Request timed out: #{ex.message}"
rescue ex : Fm::GenerationError
  puts "Generation error: #{ex.message}"
end
