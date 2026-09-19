+++
title = "Session"
description = "Conversation session management"
weight = 2
+++

## Overview

`Fm::Session` manages a conversation with the on-device model. It holds the conversation history and provides methods for generating responses, streaming, structured output, and transcript management.

## Constructors

### `.new`

```crystal
Fm::Session.new(
  model : Fm::SystemLanguageModel,
  *,
  instructions : String? = nil,
  tools : Array(Fm::Tool)? = nil,
  adapters : Array(Fm::Adapter)? = nil
)
```

Creates a new session.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model` | `SystemLanguageModel` | -- | The language model to use |
| `instructions` | `String?` | `nil` | System instructions for the model |
| `tools` | `Array(Tool)?` | `nil` | Tools available to the model |
| ~~`adapters`~~ | ~~`Array(Adapter)?`~~ | ~~`nil`~~ | **Deprecated** — AdapterAsset was removed in macOS 26.2 SDK |

### `.from_transcript`

```crystal
Fm::Session.from_transcript(
  model : Fm::SystemLanguageModel,
  transcript_json : String,
  *,
  instructions : String? = nil,
  tools : Array(Fm::Tool)? = nil
) : Fm::Session
```

Restores a session from a previously exported transcript JSON string. You can optionally provide instructions and tools to configure the restored session.

## Response Methods

### `#respond`

```crystal
session.respond(
  prompt : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default,
  *,
  context_options : Fm::ContextOptions = Fm::ContextOptions.default
) : Fm::Response
```

Sends a prompt and returns the complete response. Blocks until generation is finished.

```crystal
session.respond(
  prompt : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default,
  *,
  timeout : Time::Span,
  context_options : Fm::ContextOptions = Fm::ContextOptions.default
) : Fm::Response
```

Overload with a timeout. Raises `Fm::TimeoutError` if the timeout is exceeded. `context_options` is available on macOS 27 and controls schema inclusion and reasoning level.

### `#stream`

```crystal
session.stream(
  prompt : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default,
  *,
  context_options : Fm::ContextOptions = Fm::ContextOptions.default,
  &block : String ->
) : Nil
```

Sends a prompt and streams the response. The block receives each text chunk as it's generated.

### `#respond_json`

```crystal
session.respond_json(
  prompt : String,
  schema_json : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default,
  *,
  context_options : Fm::ContextOptions = Fm::ContextOptions.default
) : String
```

Returns a JSON string conforming to the given schema.

### `#respond_structured`

```crystal
session.respond_structured(
  type : T.class,
  prompt : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default,
  *,
  context_options : Fm::ContextOptions = Fm::ContextOptions.default
) : T forall T
```

Returns a deserialized instance of type `T`. The type must include both `JSON::Serializable` and `Fm::Generable`.

### `#stream_json`

```crystal
session.stream_json(
  prompt : String,
  schema_json : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default,
  *,
  context_options : Fm::ContextOptions = Fm::ContextOptions.default,
  &block : String ->
) : Nil
```

Streams a JSON response matching the given schema. The block receives each chunk.

## Session Control

### `#cancel`

```crystal
session.cancel : Nil
```

Cancels an ongoing generation (streaming or blocking).

### `#responding?`

```crystal
session.responding? : Bool
```

Returns `true` if the session is currently generating a response.

### `#prewarm`

```crystal
session.prewarm(prompt_prefix : String? = nil) : Nil
```

Prewarms the model with an optional prompt prefix. This can reduce latency for the next generation call.

## Transcript

### `#transcript_json`

```crystal
session.transcript_json : String
```

Exports the full conversation history as a JSON string. Use this to save and later restore sessions with `Session.from_transcript`.

## Response

### `Fm::Response`

A struct wrapping the model's text output.

| Property | Type | Description |
|----------|------|-------------|
| `content` | `String` | The generated text content |
| `usage` | `Fm::Usage?` | Per-response token usage on macOS 27; otherwise `nil` |

```crystal
response = session.respond("Hello")
puts response.content
puts response.to_s  # Same as response.content
```

### `Fm::ContextOptions`

```crystal
context = Fm::ContextOptions.new(
  include_schema_in_prompt: true,
  reasoning_level: Fm::ReasoningLevel.deep
)
response = session.respond("Solve this carefully", context_options: context)
```

Reasoning levels are `Fm::ReasoningLevel.light`, `.moderate`, `.deep`, or `.custom(value)`. These options require macOS 27. Structured generation keeps FoundationModels' default schema-in-prompt behavior unless you explicitly override it.

### `Fm::Usage`

| Property | Type | Description |
|----------|------|-------------|
| `input_tokens` | `Int64` | Tokens in the request |
| `cached_input_tokens` | `Int64` | Input tokens served from cache |
| `output_tokens` | `Int64` | Tokens the model generated |
| `reasoning_tokens` | `Int64` | Output tokens spent on reasoning |
| `total_tokens` | `Int64` | Input plus output tokens |
| `metadata` | `JSON::Any?` | Model-specific usage metadata, when reported |

`session.usage` returns cumulative session usage and `session.last_usage` returns the latest completed blocking, structured, or streamed response usage. Both return `nil` before macOS 27, as does `Fm::Response#usage`.
