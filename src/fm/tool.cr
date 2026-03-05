require "json"

module Fm
  # Output returned by a tool invocation.
  struct ToolOutput
    getter content : String

    def initialize(@content : String)
    end

    def initialize(*, json : JSON::Any)
      @content = json.to_json
    end
  end

  # A tool that can be invoked by the model.
  #
  # Implement this abstract class to define custom tools that the model
  # can call during generation.
  #
  # ```
  # class WeatherTool < Fm::Tool
  #   def name : String
  #     "checkWeather"
  #   end
  #
  #   def description : String
  #     "Check current weather conditions"
  #   end
  #
  #   def arguments_schema : JSON::Any
  #     JSON.parse(%({"type":"object","properties":{"location":{"type":"string"}},"required":["location"]}))
  #   end
  #
  #   def call(arguments : JSON::Any) : Fm::ToolOutput
  #     location = arguments["location"]?.try(&.as_s) || "Unknown"
  #     Fm::ToolOutput.new("Weather in #{location}: Sunny, 72°F")
  #   end
  # end
  # ```
  abstract class Tool
    # Returns the name of the tool.
    abstract def name : String

    # Returns a description of what the tool does.
    abstract def description : String

    # Returns the JSON schema for the tool's arguments.
    abstract def arguments_schema : JSON::Any

    # Invokes the tool with the given arguments.
    abstract def call(arguments : JSON::Any) : ToolOutput

    # :nodoc:
    # Serializes tool definitions to JSON for FFI.
    def self.tools_to_json(tools : Array(Tool)) : String
      JSON.build do |json|
        json.array do
          tools.each do |tool|
            json.object do
              json.field "name", tool.name
              json.field "description", tool.description
              json.field "argumentsSchema" do
                json.raw tool.arguments_schema.to_json
              end
            end
          end
        end
      end
    end
  end

  # :nodoc:
  # Internal result type for tool callback serialization.
  struct ToolResult
    getter success : Bool
    getter content : String?
    getter error : String?

    def initialize(@success : Bool, @content : String? = nil, @error : String? = nil)
    end

    def self.success(output : ToolOutput) : self
      new(success: true, content: output.content)
    end

    def self.error(message : String) : self
      new(success: false, error: message)
    end

    def to_json : String
      JSON.build do |json|
        json.object do
          json.field "success", @success
          json.field "content", @content if @content
          json.field "error", @error if @error
        end
      end
    end
  end
end
