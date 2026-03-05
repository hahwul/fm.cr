require "../src/fm"

# Tool calling example

class WeatherTool < Fm::Tool
  def name : String
    "checkWeather"
  end

  def description : String
    "Check current weather conditions for a location"
  end

  def arguments_schema : JSON::Any
    JSON.parse(%({"type":"object","properties":{"location":{"type":"string","description":"The city and country"}},"required":["location"]}))
  end

  def call(arguments : JSON::Any) : Fm::ToolOutput
    location = arguments["location"]?.try(&.as_s) || "Unknown"
    Fm::ToolOutput.new("Weather in #{location}: Sunny, 72°F (22°C)")
  end
end

model = Fm::SystemLanguageModel.new
model.ensure_available!

tools = [WeatherTool.new] of Fm::Tool
session = Fm::Session.new(model, instructions: "You are a helpful assistant with weather capabilities.", tools: tools)

response = session.respond("What's the weather like in Tokyo?")
puts response.content
