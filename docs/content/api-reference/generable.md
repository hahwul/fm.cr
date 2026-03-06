+++
title = "Generable & Guide"
description = "Type-safe structured output with schema generation"
weight = 3
+++

## Overview

The `Fm::Generable` module and `Fm::Guide` annotation work together to generate JSON schemas from Crystal structs and add generation constraints, enabling type-safe structured output.

## Fm::Generable

### Usage

Include `Fm::Generable` alongside `JSON::Serializable` in a struct:

```crystal
struct Character
  include JSON::Serializable
  include Fm::Generable

  getter name : String
  getter age : Int32
  getter traits : Array(String)
end
```

This generates a `json_schema` class method that returns the JSON Schema for the struct:

```crystal
Character.json_schema
# => {"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer"},"traits":{"type":"array","items":{"type":"string"}}},"required":["name","age","traits"]}
```

### Type Mapping

`Generable` maps Crystal types to JSON Schema types:

| Crystal Type | JSON Schema Type |
|-------------|------------------|
| `String` | `"string"` |
| `Int8`, `Int16`, `Int32`, `Int64` | `"integer"` |
| `UInt8`, `UInt16`, `UInt32`, `UInt64` | `"integer"` |
| `Float32`, `Float64` | `"number"` |
| `Bool` | `"boolean"` |
| `Array(T)` | `"array"` with `items` |
| Nested `Generable` type | `"object"` with properties |

### Nested Types

Types that include `Generable` are automatically supported as nested objects:

```crystal
struct Address
  include JSON::Serializable
  include Fm::Generable

  getter street : String
  getter city : String
end

struct Person
  include JSON::Serializable
  include Fm::Generable

  getter name : String
  getter address : Address
end
```

## Fm::Guide

The `@[Fm::Guide]` annotation adds JSON Schema constraints to individual fields, guiding the model's generation.

### String Constraints

```crystal
struct Config
  include JSON::Serializable
  include Fm::Generable

  @[Fm::Guide(description: "Log level setting")]
  @[Fm::Guide(any_of: ["debug", "info", "warn", "error"])]
  getter log_level : String

  @[Fm::Guide(pattern: "^[a-z][a-z0-9_]*$")]
  getter identifier : String

  @[Fm::Guide(constant: "v1")]
  getter version : String
end
```

### Numeric Constraints

```crystal
struct Range
  include JSON::Serializable
  include Fm::Generable

  @[Fm::Guide(minimum: 0, maximum: 100)]
  getter score : Int32

  @[Fm::Guide(minimum: 0.0, maximum: 1.0)]
  getter confidence : Float64
end
```

### Array Constraints

```crystal
struct TaggedItem
  include JSON::Serializable
  include Fm::Generable

  @[Fm::Guide(min_items: 1, max_items: 10)]
  getter tags : Array(String)

  @[Fm::Guide(count: 3)]
  getter top_three : Array(String)
end
```

### All Constraint Options

| Option | Type | JSON Schema | Description |
|--------|------|-------------|-------------|
| `description` | `String` | `description` | Human-readable field description |
| `any_of` | `Array` | `enum` | Restrict to specific values |
| `constant` | `Any` | `const` | Fix to a single value |
| `minimum` | `Number` | `minimum` | Minimum numeric value |
| `maximum` | `Number` | `maximum` | Maximum numeric value |
| `pattern` | `String` | `pattern` | Regex pattern for strings |
| `min_items` | `Int` | `minItems` | Minimum array length |
| `max_items` | `Int` | `maxItems` | Maximum array length |
| `count` | `Int` | `minItems` + `maxItems` | Exact array length |
