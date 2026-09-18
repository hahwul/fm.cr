+++
title = "SystemLanguageModel"
description = "The on-device language model interface"
weight = 1
+++

## Overview

`Fm::SystemLanguageModel` represents Apple's on-device foundation model. It provides methods to check availability, create sessions, count tokens, and inspect the context window size.

## Constructor

### `.new`

```crystal
Fm::SystemLanguageModel.new(
  *,
  use_case : Fm::UseCase = Fm::UseCase::General,
  guardrails : Fm::Guardrails = Fm::Guardrails::Default
)
```

Creates the default system language model.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `use_case` | `UseCase` | `General` | Model use case optimization |
| `guardrails` | `Guardrails` | `Default` | Safety guardrails level |

Raises `Fm::ModelNotAvailableError` if the model cannot be created.

## Instance Methods

### `#available?`

```crystal
model.available? : Bool
```

Returns `true` if the model is ready to generate responses.

### `#availability`

```crystal
model.availability : Fm::ModelAvailability
```

Returns the detailed availability status. Possible values:

| Value | Description |
|-------|-------------|
| `Available` | Model is ready to use |
| `DeviceNotEligible` | Device doesn't support Apple Intelligence |
| `AppleIntelligenceNotEnabled` | Apple Intelligence is disabled in System Settings |
| `ModelNotReady` | Model is still downloading |
| `Unknown` | Unknown availability state |

### `#ensure_available!`

```crystal
model.ensure_available! : Nil
```

Raises an appropriate error if the model is not available:

- `DeviceNotEligibleError` when the device doesn't support Apple Intelligence
- `AppleIntelligenceNotEnabledError` when Apple Intelligence is disabled
- `ModelNotReadyError` when the model is still downloading
- `ModelNotAvailableError` for unknown unavailability

### `#wait_until_available`

```crystal
model.wait_until_available(timeout : Time::Span) : Nil
```

Blocks until the model becomes available or the timeout is exceeded. Raises `Fm::TimeoutError` if the model is not available within the given duration.

This is especially useful when the model is in the `ModelNotReady` state (still downloading). Instead of polling `available?` manually, you can wait for readiness in a single call:

```crystal
begin
  model.wait_until_available(timeout: 60.seconds)
  puts "Model is ready!"
rescue ex : Fm::TimeoutError
  puts "Model did not become available in time."
end
```

### `#token_count_for`

```crystal
model.token_count_for(prompt : String) : Int64?
```

Returns the token count for a prompt string, or `nil` if the API is unavailable.

> Requires macOS 26.4+. Returns `nil` on older versions.

`#token_usage_for` remains available as a backward-compatible alias.

### `#token_count_for_tools`

```crystal
model.token_count_for_tools(
  instructions : String,
  tools : Array(Fm::Tool)
) : Int64?

model.token_count_for_tools(
  instructions : String,
  tools_json : String? = nil
) : Int64?
```

Returns the token count for instructions and tool definitions combined, or `nil` if the API is unavailable. Prefer the typed `Array(Fm::Tool)` overload; it uses the same normalized tool representation as `Fm::Session`. The JSON overload is available for low-level integrations and backward compatibility.

> Requires macOS 26.4+. Returns `nil` on older versions.

`#token_usage_for_tools` remains available as a backward-compatible alias.

### `#context_size`

```crystal
model.context_size : Int64?
```

Returns the maximum context window size in tokens, or `nil` if the API is unavailable.

> Available on macOS 26+ when the native extension is built with SDK 26.4 or later. Builds using an older SDK return `nil`.

## Enums

### `Fm::UseCase`

| Value | Description |
|-------|-------------|
| `General` | General-purpose language model use (default) |
| `ContentTagging` | Optimized for content tagging and classification |

### `Fm::Guardrails`

| Value | Description |
|-------|-------------|
| `Default` | Default guardrails applied to all generation |
| `PermissiveContentTransformations` | More permissive guardrails for content transformation tasks |

### `Fm::ModelAvailability`

| Value | Description |
|-------|-------------|
| `Available` | Model is ready |
| `DeviceNotEligible` | Device doesn't support Apple Intelligence |
| `AppleIntelligenceNotEnabled` | Apple Intelligence is disabled |
| `ModelNotReady` | Model is downloading |
| `Unknown` | Unknown state |
