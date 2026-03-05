<div align="center">
    <img alt="fm.cr Logo" src="resources/logo.webp" width="400px;">
</div>
<br>
    
Crystal bindings for Apple's [FoundationModels](https://developer.apple.com/documentation/foundationmodels) framework. Run on-device AI powered by Apple Intelligence directly from Crystal.

> Requires **macOS 26+** (Tahoe) with Apple Intelligence enabled.

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  fm:
    github: hahwul/fm.cr
```

2. Run `shards install`

The native Swift FFI library (`libfm_ffi.a`) is built automatically via `postinstall`.

## Quick Start

```crystal
require "fm"

model = Fm::SystemLanguageModel.new
model.ensure_available!

session = Fm::Session.new(model, instructions: "You are a helpful assistant.")
response = session.respond("What is the capital of France?")
puts response.content
```

## Features

### Basic Conversation

```crystal
session = Fm::Session.new(model, instructions: "Be concise.")

response = session.respond("What is Crystal?")
puts response.content

# Multi-turn conversation (session maintains context)
response = session.respond("What about its type system?")
puts response.content
```

### Streaming

```crystal
session = Fm::Session.new(model)

session.stream("Tell me a short story.") do |chunk|
  print chunk
  STDOUT.flush
end
puts
```

### Structured Output

Define a struct with `JSON::Serializable` and `Fm::Generable` to get typed responses:

```crystal
struct Person
  include JSON::Serializable
  include Fm::Generable

  getter name : String
  getter age : Int32
  getter occupation : String
end

person = session.respond_structured(Person, "Generate a fictional software engineer.")
puts "#{person.name}, age #{person.age} — #{person.occupation}"
```

You can also work with raw JSON schemas directly:

```crystal
schema = %({"type":"object","properties":{"city":{"type":"string"},"population":{"type":"integer"}},"required":["city","population"]})
json = session.respond_json("Largest city in Japan", schema)
puts json
```

### Tool Calling

Define tools by subclassing `Fm::Tool`:

```crystal
class WeatherTool < Fm::Tool
  def name : String
    "checkWeather"
  end

  def description : String
    "Check current weather conditions for a location"
  end

  def arguments_schema : JSON::Any
    JSON.parse(%({"type":"object","properties":{"location":{"type":"string","description":"City and country"}},"required":["location"]}))
  end

  def call(arguments : JSON::Any) : Fm::ToolOutput
    location = arguments["location"]?.try(&.as_s) || "Unknown"
    Fm::ToolOutput.new("Weather in #{location}: Sunny, 22C")
  end
end

tools = [WeatherTool.new] of Fm::Tool
session = Fm::Session.new(model, instructions: "You have weather capabilities.", tools: tools)

response = session.respond("What's the weather in Tokyo?")
puts response.content
```

### Generation Options

```crystal
options = Fm::GenerationOptions.new(
  temperature: 0.8,
  sampling: Fm::Sampling::Random,
  max_response_tokens: 500_u32
)

response = session.respond("Write a haiku.", options)
```

### Timeout

```crystal
response = session.respond("Complex question", timeout: 10.seconds)
```

### Model Availability

```crystal
model = Fm::SystemLanguageModel.new

case model.availability
when .available?
  puts "Ready"
when .device_not_eligible?
  puts "Device not eligible for Apple Intelligence"
when .apple_intelligence_not_enabled?
  puts "Enable Apple Intelligence in System Settings"
when .model_not_ready?
  puts "Model is downloading..."
end
```

### Token Usage (macOS 26.4+)

```crystal
if tokens = model.token_usage_for("Hello, world!")
  puts "Prompt tokens: #{tokens}"
end
```

### Transcript & Session Restore

```crystal
# Save conversation state
json = session.transcript_json

# Restore later
restored = Fm::Session.from_transcript(model, json)
```

### Prewarm

```crystal
session.prewarm("Tell me about")  # hint the model ahead of time
```

### Context Management

Estimate context window usage and compact long conversations:

```crystal
limit = Fm::ContextLimit.default_on_device  # 4096 tokens
usage = Fm.context_usage_from_transcript(session.transcript_json, limit)

puts "Utilization: #{(usage.utilization * 100).round(1)}%"
puts "Over limit: #{usage.over_limit?}"

# Auto-compact when over limit
if result = Fm.compact_session_if_needed(model, session, limit, base_instructions: "Be helpful.")
  session = result.session
  puts "Compacted. Summary: #{result.summary}"
end
```

## Error Handling

All errors inherit from `Fm::Error`:

| Error | Description |
|-------|-------------|
| `ModelNotAvailableError` | Model is not available |
| `DeviceNotEligibleError` | Device doesn't support Apple Intelligence |
| `AppleIntelligenceNotEnabledError` | Apple Intelligence is disabled |
| `ModelNotReadyError` | Model is still downloading |
| `GenerationError` | Generation failed |
| `TimeoutError` | Operation timed out |
| `InvalidInputError` | Invalid input provided |
| `ToolCallError` | Tool invocation failed (includes `.tool_name` and `.arguments_json`) |
| `InternalError` | Internal FFI error |

```crystal
begin
  response = session.respond("Hello")
rescue ex : Fm::TimeoutError
  puts "Timed out: #{ex.message}"
rescue ex : Fm::ToolCallError
  puts "Tool '#{ex.tool_name}' failed: #{ex.message}"
rescue ex : Fm::Error
  puts "Error: #{ex.message}"
end
```

## API Reference

### `Fm::SystemLanguageModel`

| Method | Description |
|--------|-------------|
| `.new` | Creates the default system language model |
| `#available?` | Whether the model is ready |
| `#availability` | Detailed availability status |
| `#ensure_available!` | Raises if not available |
| `#token_usage_for(prompt)` | Token count for a prompt (macOS 26.4+, returns `nil` if unavailable) |
| `#token_usage_for_tools(instructions, tools_json?)` | Token count for instructions + tools (macOS 26.4+) |

### `Fm::Session`

| Method | Description |
|--------|-------------|
| `.new(model, instructions?, tools?)` | Creates a new session |
| `.from_transcript(model, json)` | Restores from transcript JSON |
| `#respond(prompt, options?, timeout?)` | Blocking response |
| `#stream(prompt, options?) { \|chunk\| }` | Streaming response |
| `#respond_json(prompt, schema_json, options?)` | JSON response matching schema |
| `#respond_structured(Type, prompt, options?)` | Typed structured response |
| `#stream_json(prompt, schema_json, options?) { \|chunk\| }` | Streaming JSON response |
| `#transcript_json` | Export conversation transcript |
| `#prewarm(prompt_prefix?)` | Prewarm the model |
| `#cancel` | Cancel ongoing generation |
| `#responding?` | Whether generation is in progress |

### `Fm::GenerationOptions`

| Parameter | Type | Description |
|-----------|------|-------------|
| `temperature` | `Float64?` | Sampling temperature (0.0-2.0) |
| `sampling` | `Sampling?` | `Random` or `Greedy` |
| `max_response_tokens` | `UInt32?` | Maximum response length |

## Build Requirements

- **macOS 26+** (Tahoe)
- **Xcode 26+** with FoundationModels.framework
- **Crystal >= 1.19.1**
- **Swift toolchain** (included with Xcode)

## Contributing

1. Fork it (<https://github.com/hahwul/fm.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License. See [LICENSE](LICENSE) for details.
