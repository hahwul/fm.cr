<div align="center">
    <img alt="fm.cr Logo" src="resources/logo.webp" width="300px;">
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

> Schemas are rewritten into the shape FoundationModels' `GenerationSchema`
> decoder accepts (`title`, `additionalProperties`, `x-order`, `anyOf`) before
> they cross the FFI boundary, so plain JSON Schema works as written and still
> takes the native guided-generation path.

### Generation Guides

Annotate `Generable` fields with `Fm::Guide` to constrain what the model may
produce:

```crystal
struct Movie
  include JSON::Serializable
  include Fm::Generable

  @[Fm::Guide(description: "Movie title")]
  getter title : String

  @[Fm::Guide(any_of: ["G", "PG", "PG-13", "R"])]
  getter rating : String

  @[Fm::Guide(minimum: 0, maximum: 10)]
  getter score : Int32

  @[Fm::Guide(pattern: "^[A-Z]")]
  getter director : String

  @[Fm::Guide(min_items: 1, max_items: 5)]
  getter genres : Array(String)
end
```

| Option | JSON Schema keyword | Description |
|--------|---------------------|-------------|
| `description` | `description` | Human-readable field description |
| `any_of` | `enum` | Restrict the value to a set of choices |
| `constant` | `const` | Fix the field to a single value |
| `minimum` / `maximum` | `minimum` / `maximum` | Numeric bounds |
| `pattern` | `pattern` | Regex pattern for string values |
| `min_items` / `max_items` | `minItems` / `maxItems` | Array length bounds |
| `count` | `minItems` + `maxItems` | Exact array length |

Several guides may be stacked on one field; all of them apply, and the last one
wins on an option they both set.

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
  max_response_tokens: 500_u32,
  tool_calling_mode: Fm::ToolCallingMode::Allowed # macOS 27+
)

response = session.respond(
  "Write a haiku.",
  options,
  context_options: Fm::ContextOptions.new(
    reasoning_level: Fm::ReasoningLevel.moderate # macOS 27+
  )
)
if usage = response.usage
  puts "Used #{usage.total_tokens} tokens"
end
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

### Token Counting (macOS 26.4+)

```crystal
if tokens = model.token_count_for("Hello, world!")
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
limit = Fm::ContextLimit.default_on_device(model)
usage = Fm.context_usage_from_transcript(model, session.transcript, limit)

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
| `CancelledError` | The operation was cancelled by the caller |
| `InvalidInputError` | Invalid input provided |
| `ToolCallError` | Tool invocation failed (includes `.tool_name` and `.arguments_json`) |
| `UnsupportedSchemaTypeError` | A `Generable` field has no JSON Schema mapping (includes `.type_name`) |
| `InternalError` | Internal FFI error |

The following inherit from `GenerationError` and map one-to-one onto the
FoundationModels generation error cases:

| Error | Description |
|-------|-------------|
| `ExceededContextWindowSizeError` | The input exceeded the model's context window |
| `AssetsUnavailableError` | Model assets are unavailable |
| `GuardrailViolationError` | Blocked by a content-safety guardrail |
| `UnsupportedGuideError` | A generation guide constraint is not supported |
| `UnsupportedLanguageOrLocaleError` | The requested language or locale is unsupported |
| `DecodingFailureError` | The model's output could not be decoded |
| `RateLimitedError` | The request was rate-limited by the system |
| `ConcurrentRequestsError` | Multiple concurrent requests on one session |
| `RefusalError` | The model refused to generate a response |
| `InvalidGenerationSchemaError` | The provided generation schema is invalid |
| `UnsupportedCapabilityError` | The selected model does not support a requested capability (macOS 27+) |
| `UnsupportedTranscriptContentError` | The transcript contains content the model cannot process (macOS 27+) |
| `TranscriptMutationWhileRespondingError` | The transcript changed while a response was in progress (macOS 27+) |

Every `Fm::Error` exposes optional `.details` as parsed JSON. On macOS 27,
errors with associated diagnostics also provide typed accessors:

| Error | Accessors |
|-------|-----------|
| `ExceededContextWindowSizeError` | `.context_size`, `.token_count` |
| `RateLimitedError` | `.reset_date` |
| `UnsupportedGuideError` | `.schema_name` |
| `UnsupportedLanguageOrLocaleError` | `.language_code` |
| `UnsupportedCapabilityError` | `.capability` |
| `UnsupportedTranscriptContentError` | `.unsupported_content` |
| `DecodingFailureError` | `.raw_content`, `.underlying_error_message` |

```crystal
begin
  response = session.respond("Hello")
rescue ex : Fm::ExceededContextWindowSizeError
  puts "#{ex.token_count} tokens exceed the #{ex.context_size}-token context"
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
| `.new(use_case?, guardrails?)` | Creates the system language model |
| `#available?` | Whether the model is ready |
| `#availability` | Detailed availability status |
| `#ensure_available!` | Raises if not available |
| `#wait_until_available(timeout)` | Blocks until available, raising `TimeoutError` on expiry |
| `#token_count_for(prompt)` | Token count for a prompt (macOS 26.4+, returns `nil` if unavailable) |
| `#token_count_for(transcript)` | Exact token count for a complete transcript (macOS 26.4+) |
| `#token_count_for_tools(instructions, tools)` | Combined token count for instructions + typed tools (macOS 26.4+) |
| `#token_count_for_tools(instructions, tools_json?)` | Low-level JSON overload for combined token counting (macOS 26.4+) |
| `#context_size` | Maximum model context size in tokens (macOS 26+ with SDK 26.4+, returns `nil` if unavailable) |
| `#token_usage_for(...)` | Backward-compatible alias for `#token_count_for` |
| `#token_usage_for_tools(...)` | Backward-compatible alias for `#token_count_for_tools` |

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
| `#transcript` | Conversation transcript as a `Fm::Transcript` |
| `#transcript_json` | Export conversation transcript as raw JSON |
| `#prewarm(prompt_prefix?)` | Prewarm the model |
| `#cancel` | Cancel ongoing generation |
| `#responding?` | Whether generation is in progress |
| `#usage` | Cumulative token usage (macOS 27+) |
| `#last_usage` | Latest response token usage (macOS 27+) |

### `Fm::GenerationOptions`

| Parameter | Type | Description |
|-----------|------|-------------|
| `temperature` | `Float64?` | Sampling temperature (0.0-2.0) |
| `sampling` | `Sampling?` | `Random` or `Greedy` |
| `sampling_mode` | `SamplingMode?` | Advanced sampling; takes precedence over `sampling` |
| `max_response_tokens` | `UInt32?` | Maximum response length |
| `seed` | `UInt64?` | Seed for reproducible generation |
| `tool_calling_mode` | `ToolCallingMode?` | Allow, require, or disallow tool calls (macOS 27+) |

`Fm::SamplingMode` adds top-k / top-p control:

```crystal
Fm::SamplingMode.greedy
Fm::SamplingMode.random(top: 40, seed: 42_u64)              # top-k
Fm::SamplingMode.random(probability_threshold: 0.9)          # top-p (nucleus)
```

`top` and `probability_threshold` are mutually exclusive.

## Build Requirements

- **macOS 26+** (Tahoe)
- **Xcode 26+** with FoundationModels.framework
- **Crystal >= 1.21.0**
- **Swift toolchain** (included with Xcode)

> **Important:** The active developer directory must point to the full Xcode installation, not Command Line Tools. See [FAQ](#faq) if you encounter build errors.

## FAQ

### Build fails with `FoundationModelsMacros` not found

```
error: external macro implementation type 'FoundationModelsMacros.GenerableMacro'
could not be found for macro 'Generable(description:)'
```

This happens when the active developer directory is set to **Command Line Tools** instead of **Xcode**. The `@Generable` macro plugin is only available in the full Xcode installation.

**Fix:**

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

You can verify the current setting with:

```bash
xcode-select -p
# Should output: /Applications/Xcode.app/Contents/Developer
```

### Model is not available or device not eligible

Apple Intelligence must be enabled on your Mac, and the device must support it (Apple Silicon). Check **System Settings > Apple Intelligence & Siri** to enable it.

### Token counting returns `nil`

The `token_count_for` API requires **macOS 26.4+** (SDK version 26.4 or later). On older versions, it returns `nil` by design. The legacy `token_usage_for` alias behaves the same way.

## Contributing

1. Fork it (<https://github.com/hahwul/fm.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License. See [LICENSE](LICENSE) for details.
