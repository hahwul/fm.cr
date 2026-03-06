+++
title = "GenerationOptions"
description = "Control generation parameters"
weight = 4
+++

## Overview

`Fm::GenerationOptions` controls how the model generates responses, including temperature, sampling strategy, and maximum token count.

## Constructor

```crystal
Fm::GenerationOptions.new(
  temperature : Float64? = nil,
  sampling : Fm::Sampling? = nil,
  max_response_tokens : UInt32? = nil,
  seed : UInt64? = nil
)
```

All parameters are optional. When `nil`, the model uses its default values.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `temperature` | `Float64?` | `nil` | Sampling temperature (0.0 - 2.0) |
| `sampling` | `Sampling?` | `nil` | Sampling strategy |
| `max_response_tokens` | `UInt32?` | `nil` | Maximum tokens in the response |
| `seed` | `UInt64?` | `nil` | Random seed for reproducible output |

## Class Methods

### `.default`

```crystal
Fm::GenerationOptions.default : Fm::GenerationOptions
```

Returns an instance with all parameters set to `nil`, using the model's defaults.

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `temperature` | `Float64?` | Controls randomness. Lower values are more deterministic. |
| `sampling` | `Sampling?` | The sampling strategy to use. |
| `max_response_tokens` | `UInt32?` | Limits the length of the generated response. |
| `seed` | `UInt64?` | Random seed for reproducible output. |

## Fm::Sampling

| Value | Description |
|-------|-------------|
| `Random` | Random sampling with temperature (default) |
| `Greedy` | Always pick the most likely token |

## Examples

### Creative output

```crystal
options = Fm::GenerationOptions.new(
  temperature: 1.5,
  sampling: Fm::Sampling::Random,
  max_response_tokens: 1000_u32
)
```

### Deterministic output

```crystal
options = Fm::GenerationOptions.new(
  temperature: 0.0,
  sampling: Fm::Sampling::Greedy
)
```

### Reproducible output

```crystal
options = Fm::GenerationOptions.new(
  temperature: 0.0,
  sampling: Fm::Sampling::Greedy,
  seed: 42_u64
)
```

### Concise output

```crystal
options = Fm::GenerationOptions.new(
  max_response_tokens: 100_u32
)
```
