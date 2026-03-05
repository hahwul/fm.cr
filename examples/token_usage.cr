require "../src/fm"

# Token usage API example (requires macOS 26.4+)

model = Fm::SystemLanguageModel.new
model.ensure_available!

# Check token usage for a prompt
if tokens = model.token_usage_for("Hello, how are you today?")
  puts "Prompt tokens: #{tokens}"
else
  puts "Token usage API not available on this OS version."
end

# Check token usage for instructions + tools
tools_json = %([{"name":"search","description":"Search the web","argumentsSchema":{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}}])
if tokens = model.token_usage_for_tools("You are a helpful assistant.", tools_json)
  puts "Instructions + tools tokens: #{tokens}"
else
  puts "Token usage API not available on this OS version."
end
