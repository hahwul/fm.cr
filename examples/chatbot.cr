require "../src/fm"

# Simple interactive chatbot using Apple FoundationModels

model = Fm::SystemLanguageModel.new
model.ensure_available!

session = Fm::Session.new(model, instructions: "You are a friendly chatbot. Be helpful and concise.")

puts "Chatbot ready! Type your message (or 'quit' to exit)"
puts "---"

loop do
  print "> "
  STDOUT.flush

  input = gets
  break if input.nil?

  input = input.strip
  break if input.empty? || input.downcase == "quit"

  response = session.respond(input)
  puts "Bot: #{response.content}"
  puts
end

puts "Bye!"
