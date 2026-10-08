# Runs against the real model, so it needs `ext/libfm_ffi.a` built and Apple
# Intelligence available. Compiled only with FM_INTEGRATION=1:
#
#   FM_INTEGRATION=1 crystal spec spec/integration_spec.cr
{% if env("FM_INTEGRATION") == "1" %}
  require "./spec_helper"

  private class SleepyWeatherTool < Fm::Tool
    getter calls = 0

    def name : String
      "checkWeather"
    end

    def description : String
      "Check current weather conditions for a location"
    end

    def arguments_schema : JSON::Any
      JSON.parse(%({"type":"object","properties":{"location":{"type":"string"}},"required":["location"]}))
    end

    def call(arguments : JSON::Any) : Fm::ToolOutput
      sleep 1.millisecond # touches the scheduler: segfaulted on a Swift thread
      @calls += 1
      Fm::ToolOutput.new("Sunny, 22C")
    end
  end

  private def weather_session(tool)
    Fm::Session.new(Fm::SystemLanguageModel.new,
      instructions: "Always use the weather tool.", tools: [tool] of Fm::Tool)
  end

  describe "callbacks from the native layer" do
    it "runs the stream block and tools on a Crystal thread" do
      tool = SleepyWeatherTool.new
      text = String.build do |io|
        weather_session(tool).stream("What's the weather in Tokyo?") do |chunk|
          sleep 1.millisecond
          io << chunk
        end
      end
      text.should_not be_empty
      tool.calls.should be > 0
    end

    it "runs tools on a Crystal thread" do
      tool = SleepyWeatherTool.new
      weather_session(tool).respond("What's the weather in Tokyo?")
      tool.calls.should be > 0
    end

    it "runs tools on a Crystal thread under a timeout" do
      tool = SleepyWeatherTool.new
      weather_session(tool).respond("What's the weather in Tokyo?", timeout: 60.seconds)
      tool.calls.should be > 0
    end
  end
{% end %}
