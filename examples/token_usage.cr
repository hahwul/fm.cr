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

# macOS 27+: FoundationModels reports exact token usage per response, and lets
# you steer how much reasoning a request gets. Both are `nil` / ignored on
# macOS 26, so the same code keeps working there.
session = Fm::Session.new(model, instructions: "You are a helpful assistant. Be concise.")

response = session.respond(
  "Summarize the water cycle in one sentence.",
  Fm::GenerationOptions.new(tool_calling_mode: Fm::ToolCallingMode::Disallowed),
  context_options: Fm::ContextOptions.new(reasoning_level: Fm::ReasoningLevel.light)
)
puts "Response: #{response.content}"

if usage = response.usage
  puts "Input tokens: #{usage.input_tokens} (#{usage.cached_input_tokens} cached)"
  puts "Output tokens: #{usage.output_tokens} (#{usage.reasoning_tokens} reasoning)"
  puts "Total tokens: #{usage.total_tokens}"
else
  puts "Response usage requires macOS 27."
end

# Streaming reports usage too — read it once the stream is done.
session.stream(
  "Name one river.",
  context_options: Fm::ContextOptions.new(reasoning_level: Fm::ReasoningLevel.light)
) { |chunk| print chunk }
puts

if usage = session.last_usage
  puts "Streamed response used #{usage.total_tokens} tokens"
end

# Cumulative usage across every turn of the session.
if usage = session.usage
  puts "Session total: #{usage.total_tokens} tokens"
end

# The other request entry points take `context_options` too.
struct Fact
  include JSON::Serializable
  include Fm::Generable

  getter claim : String
end

deep = Fm::ContextOptions.new(reasoning_level: Fm::ReasoningLevel.deep)

fact = session.respond_structured(Fact, "State one fact about tides.", context_options: deep)
puts "Fact: #{fact.claim}"
puts "Structured response used #{session.last_usage.try(&.total_tokens) || 0} tokens"

begin
  reply = session.respond(
    "Name one tide-related term.",
    timeout: 10.seconds,
    context_options: deep
  )
  puts "Reply: #{reply.content}"
rescue ex : Fm::TimeoutError
  puts "Request timed out: #{ex.message}"
end

session.stream_json(
  "Give one tide fact.",
  Fact.json_schema.to_json,
  context_options: deep
) { |chunk| print chunk }
puts
