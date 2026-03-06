+++
title = "Structured Output"
description = "Type-safe responses with Generable and JSON schemas"
weight = 4
+++

## Overview

fm.cr supports generating structured output that conforms to a JSON schema. You can either define Crystal structs with the `Generable` module for type-safe deserialization, or work with raw JSON schemas directly.

## Using Generable

Include both `JSON::Serializable` and `Fm::Generable` in a struct to automatically generate a JSON schema and deserialize responses:

```crystal
struct Person
  include JSON::Serializable
  include Fm::Generable

  getter name : String
  getter age : Int32
  getter occupation : String
end

person = session.respond_structured(Person, "Generate a fictional software engineer.")
puts "#{person.name}, age #{person.age} -- #{person.occupation}"
```

`Generable` automatically maps Crystal types to JSON Schema types:

| Crystal Type | JSON Schema Type |
|-------------|------------------|
| `String` | `string` |
| `Int32`, `Int64`, etc. | `integer` |
| `Float32`, `Float64` | `number` |
| `Bool` | `boolean` |
| `Array(T)` | `array` |
| Nested `Generable` types | `object` |

## Guide Annotations

Use the `@[Fm::Guide]` annotation to add constraints that guide the model's generation:

```crystal
struct MovieReview
  include JSON::Serializable
  include Fm::Generable

  @[Fm::Guide(description: "The movie title")]
  getter title : String

  @[Fm::Guide(any_of: ["positive", "negative", "neutral"])]
  getter sentiment : String

  @[Fm::Guide(minimum: 1, maximum: 10)]
  getter rating : Int32

  @[Fm::Guide(min_items: 1, max_items: 5)]
  getter tags : Array(String)
end
```

### Available Guide Constraints

| Constraint | Type | Description |
|-----------|------|-------------|
| `description` | `String` | Human-readable field description |
| `any_of` | `Array` | Restrict string to specific values (JSON Schema `enum`) |
| `constant` | `Any` | Fix field to a single constant value |
| `minimum` | `Number` | Minimum numeric value |
| `maximum` | `Number` | Maximum numeric value |
| `pattern` | `String` | Regex pattern for string values |
| `min_items` | `Int` | Minimum array length |
| `max_items` | `Int` | Maximum array length |
| `count` | `Int` | Exact array length (sets both `minItems` and `maxItems`) |

## Raw JSON Schema

For more control, use `respond_json` with a JSON schema string directly:

```crystal
schema = %({"type":"object","properties":{"city":{"type":"string"},"population":{"type":"integer"}},"required":["city","population"]})

json = session.respond_json("Largest city in Japan", schema)
puts json  # => {"city":"Tokyo","population":13960000}
```

The return value is a raw JSON string. Parse it with `JSON.parse` if needed:

```crystal
data = JSON.parse(json)
puts data["city"]        # => Tokyo
puts data["population"]  # => 13960000
```

## Streaming Structured Output

Combine structured output with streaming using `stream_json`:

```crystal
schema = %({"type":"object","properties":{"name":{"type":"string"},"bio":{"type":"string"}},"required":["name","bio"]})

session.stream_json("Generate a character profile.", schema) do |chunk|
  print chunk
  STDOUT.flush
end
puts
```
