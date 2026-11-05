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

  private class FailingWeatherTool < SleepyWeatherTool
    def call(arguments : JSON::Any) : Fm::ToolOutput
      raise "weather service down"
    end
  end

  describe "tool failures" do
    it "raise ToolCallError with the tool context from respond" do
      error = expect_raises(Fm::ToolCallError) do
        weather_session(FailingWeatherTool.new).respond("What's the weather in Tokyo?")
      end
      error.tool_name.should eq("checkWeather")
      error.message.not_nil!.should contain("weather service down")
    end

    it "raise ToolCallError from stream" do
      expect_raises(Fm::ToolCallError, /weather service down/) do
        weather_session(FailingWeatherTool.new).stream("What's the weather in Tokyo?") { }
      end
    end
  end

  describe "Session.from_transcript" do
    it "applies instructions to a transcript without any" do
      empty = Fm::Session.new(Fm::SystemLanguageModel.new).transcript_json
      session = Fm::Session.from_transcript(Fm::SystemLanguageModel.new, empty, instructions: "Be terse.")
      entry = session.transcript.entries.first
      entry["role"].should eq("instructions")
      entry["contents"][0]["text"].should eq("Be terse.")
    end

    it "keeps the instructions a transcript already has" do
      original = Fm::Session.new(Fm::SystemLanguageModel.new, instructions: "Original.").transcript_json
      session = Fm::Session.from_transcript(Fm::SystemLanguageModel.new, original, instructions: "Other.")
      entries = session.transcript.entries
      entries.size.should eq(1)
      entries.first["contents"][0]["text"].should eq("Original.")
    end
  end

  describe "token counting malformed input" do
    it "raises InvalidInputError for malformed tools JSON" do
      expect_raises(Fm::InvalidInputError, /tools JSON/) do
        Fm::SystemLanguageModel.new.token_count_for_tools("Be terse.", "not json")
      end
    end

    it "raises InvalidInputError for a malformed transcript" do
      expect_raises(Fm::InvalidInputError, /transcript/) do
        Fm::SystemLanguageModel.new.token_count_for(Fm::Transcript.new("{}"))
      end
    end
  end
{% end %}
