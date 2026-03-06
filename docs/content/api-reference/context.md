+++
title = "Context"
description = "Context window management and session compaction"
weight = 6
+++

## Module Functions

These functions are available on the `Fm` module directly.

### `Fm.context_usage_from_transcript`

```crystal
Fm.context_usage_from_transcript(
  transcript_json : String,
  limit : Fm::ContextLimit
) : Fm::ContextUsage
```

Estimates token usage from a transcript JSON string and context limit configuration.

### `Fm.estimate_tokens`

```crystal
Fm.estimate_tokens(text : String, chars_per_token : Int32) : Int32
```

Estimates the number of tokens in a text string using a characters-per-token heuristic.

### `Fm.transcript_to_text`

```crystal
Fm.transcript_to_text(transcript_json : String) : String
```

Extracts human-readable text from a transcript JSON string.

### `Fm.compact_transcript`

```crystal
Fm.compact_transcript(
  model : Fm::SystemLanguageModel,
  transcript_json : String,
  config : Fm::CompactionConfig = Fm::CompactionConfig.new
) : String
```

Compacts a transcript into a summary string using the on-device model.

### `Fm.compact_session_if_needed`

```crystal
Fm.compact_session_if_needed(
  model : Fm::SystemLanguageModel,
  session : Fm::Session,
  limit : Fm::ContextLimit,
  config : Fm::CompactionConfig = Fm::CompactionConfig.new,
  base_instructions : String? = nil
) : Fm::CompactedSession?
```

Checks if the session's context usage exceeds the limit. If so, compacts the session and returns a `CompactedSession`. Returns `nil` if compaction is not needed.

### `Fm.session_from_summary`

```crystal
Fm.session_from_summary(
  model : Fm::SystemLanguageModel,
  base_instructions : String?,
  summary : String
) : Fm::Session
```

Creates a new session with the summary prepended to the base instructions.

## Fm::ContextLimit

Configuration for context window boundaries.

### Constructor

```crystal
Fm::ContextLimit.new(
  max_tokens : Int32 = 4096,
  reserved_response_tokens : Int32 = 0,
  chars_per_token : Int32 = 4
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_tokens` | `Int32` | `4096` | Maximum tokens in the context window |
| `reserved_response_tokens` | `Int32` | `0` | Tokens reserved for the next response |
| `chars_per_token` | `Int32` | `4` | Estimated characters per token |

### Class Methods

#### `.default_on_device`

```crystal
Fm::ContextLimit.default_on_device : Fm::ContextLimit
```

Returns the default context limit for Apple's on-device models (4096 tokens).

## Fm::ContextUsage

Token usage estimation results.

| Property | Type | Description |
|----------|------|-------------|
| `estimated_tokens` | `Int32` | Estimated tokens consumed by transcript |
| `max_tokens` | `Int32` | Maximum tokens configured |
| `reserved_response_tokens` | `Int32` | Tokens reserved for next response |
| `available_tokens` | `Int32` | Estimated tokens remaining |
| `utilization` | `Float32` | Usage ratio (0.0 - 1.0+) |
| `over_limit?` | `Bool` | Whether estimate exceeds available budget |

## Fm::CompactionConfig

Controls how transcripts are summarized during compaction.

### Constructor

```crystal
Fm::CompactionConfig.new(
  chunk_tokens : Int32 = 800,
  max_summary_tokens : Int32 = 400,
  instructions : String = "...",
  summary_options : Fm::GenerationOptions = ...,
  chars_per_token : Int32 = 4
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `chunk_tokens` | `Int32` | `800` | Size of transcript chunks to summarize |
| `max_summary_tokens` | `Int32` | `400` | Maximum tokens in the summary |
| `instructions` | `String` | (built-in) | Instructions for the summarization model |
| `summary_options` | `GenerationOptions` | temp: 0.2, max: 256 | Generation options for summarization |
| `chars_per_token` | `Int32` | `4` | Characters per token estimate |

## Fm::CompactedSession

Result of a successful session compaction.

| Property | Type | Description |
|----------|------|-------------|
| `session` | `Session` | The new compacted session |
| `summary` | `String` | The generated conversation summary |

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `DEFAULT_CONTEXT_TOKENS` | `4096` | Default context window size for on-device models |
