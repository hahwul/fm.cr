+++
title = "Tool Calling"
description = "Extend model capabilities with custom tools"
weight = 5
+++

## Overview

Tool calling lets the model invoke functions you define during a conversation. The model decides when to use a tool based on the conversation context, calls it with appropriate arguments, and incorporates the result into its response.

## Defining a Tool

Create a tool by subclassing `Fm::Tool` and implementing four abstract methods:

```crystal
class WeatherTool < Fm::Tool
  def name : String
    "checkWeather"
  end

  def description : String
    "Check current weather conditions for a location"
  end

  def arguments_schema : JSON::Any
    JSON.parse(%({"type":"object","properties":{"location":{"type":"string","description":"City and country"}},"required":["location"]}))
  end

  def call(arguments : JSON::Any) : Fm::ToolOutput
    location = arguments["location"]?.try(&.as_s) || "Unknown"
    Fm::ToolOutput.new("Weather in #{location}: Sunny, 22C")
  end
end
```

### Tool Interface

| Method | Return Type | Description |
|--------|-------------|-------------|
| `name` | `String` | Unique identifier for the tool |
| `description` | `String` | What the tool does (helps the model decide when to use it) |
| `arguments_schema` | `JSON::Any` | JSON Schema defining the tool's input parameters |
| `call(arguments)` | `Fm::ToolOutput` | Execute the tool and return a result |

## Registering Tools

Pass tools when creating a session:

```crystal
tools = [WeatherTool.new] of Fm::Tool

session = Fm::Session.new(
  model,
  instructions: "You have weather capabilities.",
  tools: tools
)
```

## Using Tools in Conversation

Once registered, the model will automatically call tools when appropriate:

```crystal
response = session.respond("What's the weather in Tokyo?")
puts response.content
# => The weather in Tokyo is currently sunny with a temperature of 22°C.
```

The flow is:

1. The model receives your prompt
2. It decides to call `checkWeather` with `{"location": "Tokyo"}`
3. Your `call` method executes and returns the result
4. The model incorporates the tool output into its response

## ToolOutput

`ToolOutput` wraps the result returned from a tool call:

```crystal
# From a string
Fm::ToolOutput.new("Result text")

# From JSON
Fm::ToolOutput.new(json: JSON.parse(%({"temperature": 22, "condition": "sunny"})))
```

## Multiple Tools

Register multiple tools by including them all in the array:

```crystal
tools = [
  WeatherTool.new,
  CalculatorTool.new,
  SearchTool.new,
] of Fm::Tool

session = Fm::Session.new(model, instructions: "You have various capabilities.", tools: tools)
```

## Error Handling

If a tool call fails, it raises `Fm::ToolCallError` which includes the tool name and arguments:

```crystal
begin
  response = session.respond("Check the weather")
rescue ex : Fm::ToolCallError
  puts "Tool: #{ex.tool_name}"
  puts "Arguments: #{ex.arguments_json}"
  puts "Error: #{ex.message}"
end
```
