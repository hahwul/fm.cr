+++
title = "Context Management"
description = "Transcripts, token estimation, and session compaction"
weight = 6
+++

## Overview

Long conversations can exceed the model's context window. fm.cr provides tools to monitor context usage, export and restore conversation state, and automatically compact sessions when needed.

## Transcripts

Export the current conversation as JSON for persistence or analysis:

```crystal
# Save conversation state
json = session.transcript_json

# Restore later
restored = Fm::Session.from_transcript(model, json)
response = restored.respond("Continue our conversation.")

# Restore with instructions and tools
restored = Fm::Session.from_transcript(model, json,
  instructions: "You are a helpful assistant.",
  tools: [my_tool]
)
```

Convert a transcript to readable text:

```crystal
text = Fm.transcript_to_text(session.transcript_json)
puts text
```

## Context Usage Estimation

Monitor how much of the context window is consumed:

```crystal
limit = Fm::ContextLimit.default_on_device  # 4096 tokens
usage = Fm.context_usage_from_transcript(session.transcript_json, limit)

puts "Estimated tokens: #{usage.estimated_tokens}"
puts "Available tokens: #{usage.available_tokens}"
puts "Utilization: #{(usage.utilization * 100).round(1)}%"
puts "Over limit: #{usage.over_limit?}"
```

### ContextLimit

Configure the context window parameters:

```crystal
# Default on-device limit (4096 tokens)
limit = Fm::ContextLimit.default_on_device

# Custom limit
limit = Fm::ContextLimit.new(
  max_tokens: 4096,
  reserved_response_tokens: 512,
  chars_per_token: 4
)
```

### ContextUsage

The `ContextUsage` struct provides these fields:

| Field | Type | Description |
|-------|------|-------------|
| `estimated_tokens` | `Int32` | Estimated tokens consumed by transcript |
| `max_tokens` | `Int32` | Maximum tokens configured |
| `reserved_response_tokens` | `Int32` | Tokens reserved for next response |
| `available_tokens` | `Int32` | Estimated tokens remaining |
| `utilization` | `Float32` | Usage ratio (0.0 - 1.0+) |
| `over_limit?` | `Bool` | Whether estimate exceeds budget |

## Automatic Compaction

When a conversation gets too long, compact it by summarizing earlier messages and starting a fresh session:

```crystal
limit = Fm::ContextLimit.default_on_device

if result = Fm.compact_session_if_needed(model, session, limit, base_instructions: "Be helpful.")
  session = result.session
  puts "Compacted. Summary: #{result.summary}"
end
```

The method returns `nil` if compaction is not needed (context is within limits).

### CompactionConfig

Customize the compaction behavior:

```crystal
config = Fm::CompactionConfig.new(
  chunk_tokens: 800,
  max_summary_tokens: 400,
  instructions: "Summarize the conversation concisely.",
  summary_options: Fm::GenerationOptions.new(
    temperature: 0.2,
    max_response_tokens: 256_u32
  )
)

result = Fm.compact_session_if_needed(model, session, limit, config: config)
```

## Manual Compaction

Compact a transcript directly without checking limits:

```crystal
summary = Fm.compact_transcript(model, session.transcript_json)
puts summary
```

Create a new session from a summary:

```crystal
new_session = Fm.session_from_summary(model, "Be helpful.", summary)
```

## Token Estimation

Estimate tokens for arbitrary text:

```crystal
tokens = Fm.estimate_tokens("Hello, world!", chars_per_token: 4)
puts tokens  # => 4
```
