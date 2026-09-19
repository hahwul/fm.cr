+++
title = "Errors"
description = "Error types and exception handling"
weight = 7
+++

## Overview

All fm.cr errors inherit from `Fm::Error`, which itself inherits from `Exception`. This allows you to catch all fm.cr errors with a single rescue clause or handle specific error types individually.

## Error Hierarchy

```
Exception
  └── Fm::Error
        ├── Fm::ModelNotAvailableError
        ├── Fm::DeviceNotEligibleError
        ├── Fm::AppleIntelligenceNotEnabledError
        ├── Fm::ModelNotReadyError
        ├── Fm::InvalidInputError
        ├── Fm::GenerationError
        │     ├── Fm::ExceededContextWindowSizeError
        │     ├── Fm::AssetsUnavailableError
        │     ├── Fm::GuardrailViolationError
        │     ├── Fm::UnsupportedGuideError
        │     ├── Fm::UnsupportedLanguageOrLocaleError
        │     ├── Fm::DecodingFailureError
        │     ├── Fm::RateLimitedError
        │     ├── Fm::ConcurrentRequestsError
        │     ├── Fm::RefusalError
        │     ├── Fm::InvalidGenerationSchemaError
        │     ├── Fm::UnsupportedCapabilityError
        │     ├── Fm::UnsupportedTranscriptContentError
        │     └── Fm::TranscriptMutationWhileRespondingError
        ├── Fm::TimeoutError
        ├── Fm::ToolCallError
        └── Fm::InternalError
```

## Error Types

### Availability Errors

| Error | Description |
|-------|-------------|
| `ModelNotAvailableError` | Model is not available for an unspecified reason |
| `DeviceNotEligibleError` | Device doesn't support Apple Intelligence |
| `AppleIntelligenceNotEnabledError` | Apple Intelligence is disabled in System Settings |
| `ModelNotReadyError` | Model is still downloading |

### Generation Errors

| Error | Description |
|-------|-------------|
| `GenerationError` | Generation failed |
| `ExceededContextWindowSizeError` | Input exceeds the context window |
| `AssetsUnavailableError` | Required model assets are unavailable |
| `GuardrailViolationError` | Generation blocked by safety guardrails |
| `RateLimitedError` | Too many requests in a short time |
| `ConcurrentRequestsError` | Multiple concurrent requests to the same session |
| `RefusalError` | Model refused to generate a response |
| `UnsupportedCapabilityError` | The selected model doesn't support a requested capability (macOS 27+) |
| `UnsupportedTranscriptContentError` | The transcript contains content the model cannot process (macOS 27+) |
| `TranscriptMutationWhileRespondingError` | The transcript changed while a response was in progress (macOS 27+) |

### Input/Schema Errors

| Error | Description |
|-------|-------------|
| `InvalidInputError` | Invalid input provided |
| `UnsupportedGuideError` | Unsupported guide constraint |
| `UnsupportedLanguageOrLocaleError` | Unsupported language or locale |
| `DecodingFailureError` | Failed to decode structured output |
| `InvalidGenerationSchemaError` | Invalid JSON schema for generation |

### Tool Errors

| Error | Description |
|-------|-------------|
| `ToolCallError` | Tool invocation failed |

`ToolCallError` provides additional context:

| Property | Type | Description |
|----------|------|-------------|
| `tool_name` | `String` | Name of the tool that failed |
| `arguments_json` | `String?` | JSON string of the arguments passed to the tool |

### Structured Details

Every `Fm::Error` has an optional `details : JSON::Any?` property. When an
error raised by macOS 27 includes associated diagnostic information, fm.cr
preserves it for both blocking and streaming calls. Older SDKs and errors
without associated information return `nil`.

Common fields also have typed accessors:

| Error | Property | Type |
|-------|----------|------|
| `ExceededContextWindowSizeError` | `context_size`, `token_count` | `Int64?` |
| `RateLimitedError` | `reset_date` | `Time?` |
| `UnsupportedGuideError` | `schema_name` | `String?` |
| `UnsupportedLanguageOrLocaleError` | `language_code` | `String?` |
| `UnsupportedCapabilityError` | `capability` | `String?` |
| `UnsupportedTranscriptContentError` | `unsupported_content` | `Array(JSON::Any)?` |
| `DecodingFailureError` | `raw_content`, `underlying_error_message` | `String?` |

The generic `details` object also contains `version`, `debugDescription`, and
stringified FoundationModels `metadata` when the framework supplies them.

### Other Errors

| Error | Description |
|-------|-------------|
| `TimeoutError` | Operation timed out |
| `InternalError` | Internal FFI error |

## Usage Example

```crystal
begin
  response = session.respond("Hello")
rescue ex : Fm::ExceededContextWindowSizeError
  puts "Used #{ex.token_count} of #{ex.context_size} tokens"
rescue ex : Fm::TimeoutError
  puts "Timed out: #{ex.message}"
rescue ex : Fm::ToolCallError
  puts "Tool '#{ex.tool_name}' failed: #{ex.message}"
  puts "Arguments: #{ex.arguments_json}" if ex.arguments_json
rescue ex : Fm::GuardrailViolationError
  puts "Blocked by guardrails: #{ex.message}"
rescue ex : Fm::RateLimitedError
  puts "Rate limited, try again later"
rescue ex : Fm::Error
  puts "fm.cr error: #{ex.message}"
end
```

## Error Codes

Errors are mapped from Swift error codes returned by the FFI layer. The mapping is handled internally by `Fm.error_from_swift`.
