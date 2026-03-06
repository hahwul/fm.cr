+++
title = "Basic Usage"
description = "Models, sessions, and generating responses"
weight = 2
+++

## Creating a Model

The `SystemLanguageModel` represents Apple's on-device foundation model. Create one with default settings or customize it with use case and guardrail options:

```crystal
require "fm"

# Default model
model = Fm::SystemLanguageModel.new

# With specific use case and guardrails
model = Fm::SystemLanguageModel.new(
  use_case: Fm::UseCase::ContentTagging,
  guardrails: Fm::Guardrails::PermissiveContentTransformations
)
```

### Use Cases

| Value | Description |
|-------|-------------|
| `UseCase::General` | General-purpose language model use (default) |
| `UseCase::ContentTagging` | Optimized for content tagging and classification |

### Guardrails

| Value | Description |
|-------|-------------|
| `Guardrails::Default` | Default guardrails applied to all generation |
| `Guardrails::PermissiveContentTransformations` | More permissive guardrails for content transformation tasks |

## Creating a Session

A `Session` holds conversation state between you and the model. You can provide system instructions and tools:

```crystal
session = Fm::Session.new(model, instructions: "You are a helpful assistant.")
```

Sessions maintain multi-turn conversation context automatically.

## Generating Responses

Use `respond` for a blocking call that returns the complete response:

```crystal
response = session.respond("What is Crystal?")
puts response.content

# Follow-up (session maintains context)
response = session.respond("What about its type system?")
puts response.content
```

### With a Timeout

Set a timeout to limit how long the model can take:

```crystal
response = session.respond("Complex question", timeout: 10.seconds)
puts response.content
```

### With Generation Options

Customize temperature, sampling strategy, and max tokens:

```crystal
options = Fm::GenerationOptions.new(
  temperature: 0.8,
  sampling: Fm::Sampling::Random,
  max_response_tokens: 500_u32
)

response = session.respond("Write a haiku.", options)
puts response.content
```

## Error Handling

All fm.cr errors inherit from `Fm::Error`. Use specific error types for targeted handling:

```crystal
begin
  response = session.respond("Hello")
rescue ex : Fm::TimeoutError
  puts "Timed out: #{ex.message}"
rescue ex : Fm::ToolCallError
  puts "Tool '#{ex.tool_name}' failed: #{ex.message}"
rescue ex : Fm::GuardrailViolationError
  puts "Guardrail violation: #{ex.message}"
rescue ex : Fm::Error
  puts "Error: #{ex.message}"
end
```

See the [Errors](/api-reference/errors/) reference for the complete list.

## Token Usage

Estimate how many tokens a prompt will use (requires macOS 26.4+):

```crystal
if tokens = model.token_usage_for("Hello, world!")
  puts "Prompt tokens: #{tokens}"
end
```

You can also estimate token usage for instructions and tools configuration:

```crystal
if tokens = model.token_usage_for_tools("You are a helpful assistant.", tools_json)
  puts "System tokens: #{tokens}"
end
```

## Prewarming

Hint the model ahead of time with a prompt prefix to reduce latency:

```crystal
session.prewarm("Tell me about")
```
