+++
title = "Tools"
description = "Tool calling API reference"
weight = 5
+++

## Fm::Tool

An abstract class for defining tools that the model can call during generation.

### Abstract Methods

Subclasses must implement all four methods:

```crystal
class MyTool < Fm::Tool
  def name : String
    "myTool"
  end

  def description : String
    "Description of what this tool does"
  end

  def arguments_schema : JSON::Any
    JSON.parse(%({"type":"object","properties":{...},"required":[...]}))
  end

  def call(arguments : JSON::Any) : Fm::ToolOutput
    # Execute and return result
    Fm::ToolOutput.new("result")
  end
end
```

| Method | Return Type | Description |
|--------|-------------|-------------|
| `name` | `String` | Unique identifier for the tool |
| `description` | `String` | Describes what the tool does |
| `arguments_schema` | `JSON::Any` | JSON Schema for the tool's input |
| `call(arguments)` | `ToolOutput` | Executes the tool with parsed arguments |

### Class Methods

#### `.tools_to_json`

```crystal
Fm::Tool.tools_to_json(tools : Array(Fm::Tool)) : String
```

Serializes an array of tool definitions to a JSON string for the FFI layer. This is used internally when creating sessions with tools.

## Fm::ToolOutput

A struct wrapping the result of a tool invocation.

### Constructors

```crystal
# From a string
Fm::ToolOutput.new(content : String)

# From JSON
Fm::ToolOutput.new(json: JSON::Any)
```

| Constructor | Description |
|------------|-------------|
| `.new(content)` | Creates output from a plain string |
| `.new(json:)` | Creates output from a `JSON::Any` value (serialized to string) |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `content` | `String` | The tool's output content |

## Arguments Schema

The `arguments_schema` should return a valid JSON Schema object describing the tool's expected input. The model uses this schema to construct valid arguments.

```crystal
def arguments_schema : JSON::Any
  JSON.parse(<<-JSON
    {
      "type": "object",
      "properties": {
        "query": {
          "type": "string",
          "description": "The search query"
        },
        "limit": {
          "type": "integer",
          "description": "Maximum number of results"
        }
      },
      "required": ["query"]
    }
  JSON
  )
end
```
