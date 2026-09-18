require "../src/fm"

# Token usage API example (requires macOS 26.4+)

class SearchTool < Fm::Tool
  def name : String
    "search"
  end

  def description : String
    "Search the web"
  end

  def arguments_schema : JSON::Any
    JSON.parse(%({"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}))
  end

  def call(arguments : JSON::Any) : Fm::ToolOutput
    Fm::ToolOutput.new("No search performed")
  end
end

model = Fm::SystemLanguageModel.new
model.ensure_available!

# Check the model's context window size
if context_size = model.context_size
  puts "Context size: #{context_size} tokens"
end

# Count tokens for a prompt
if tokens = model.token_count_for("Hello, how are you today?")
  puts "Prompt tokens: #{tokens}"
else
  puts "Token usage API not available on this OS version."
end

# Count tokens for instructions + tools
tools = [SearchTool.new] of Fm::Tool
if tokens = model.token_count_for_tools("You are a helpful assistant.", tools)
  puts "Instructions + tools tokens: #{tokens}"
else
  puts "Token usage API not available on this OS version."
end
