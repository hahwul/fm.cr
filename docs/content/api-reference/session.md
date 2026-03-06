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
  tools : Array(Fm::Tool)? = nil
)
```

Creates a new session.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model` | `SystemLanguageModel` | -- | The language model to use |
| `instructions` | `String?` | `nil` | System instructions for the model |
| `tools` | `Array(Tool)?` | `nil` | Tools available to the model |

### `.from_transcript`

```crystal
Fm::Session.from_transcript(
  model : Fm::SystemLanguageModel,
  transcript_json : String
) : Fm::Session
```

Restores a session from a previously exported transcript JSON string.

## Response Methods

### `#respond`

```crystal
session.respond(
  prompt : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default
) : Fm::Response
```

Sends a prompt and returns the complete response. Blocks until generation is finished.

```crystal
session.respond(
  prompt : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default,
  *,
  timeout : Time::Span
) : Fm::Response
```

Overload with a timeout. Raises `Fm::TimeoutError` if the timeout is exceeded.

### `#stream`

```crystal
session.stream(
  prompt : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default,
  &block : String ->
) : Nil
```

Sends a prompt and streams the response. The block receives each text chunk as it's generated.

### `#respond_json`

```crystal
session.respond_json(
  prompt : String,
  schema_json : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default
) : String
```

Returns a JSON string conforming to the given schema.

### `#respond_structured`

```crystal
session.respond_structured(
  type : T.class,
  prompt : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default
) : T forall T
```

Returns a deserialized instance of type `T`. The type must include both `JSON::Serializable` and `Fm::Generable`.

### `#stream_json`

```crystal
session.stream_json(
  prompt : String,
  schema_json : String,
  options : Fm::GenerationOptions = Fm::GenerationOptions.default,
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

```crystal
response = session.respond("Hello")
puts response.content
puts response.to_s  # Same as response.content
```
