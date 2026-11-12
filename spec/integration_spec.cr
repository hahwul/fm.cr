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

    it "raise ToolCallError with the tool context from stream" do
      error = expect_raises(Fm::ToolCallError, /weather service down/) do
        weather_session(FailingWeatherTool.new).stream("What's the weather in Tokyo?") { }
      end
      error.tool_name.should eq("checkWeather")
      error.arguments_json.not_nil!.should contain("location")
    end
  end

  private class NoArgsTool < Fm::Tool
    def name : String
      "getServerTime"
    end

    def description : String
      "Returns the current server time"
    end

    def arguments_schema : JSON::Any
      JSON.parse("{}")
    end

    def call(arguments : JSON::Any) : Fm::ToolOutput
      Fm::ToolOutput.new("12:34")
    end
  end

  describe "a tool with an empty arguments schema" do
    it "is registered natively under its own name" do
      session = Fm::Session.new(Fm::SystemLanguageModel.new,
        instructions: "Be terse.", tools: [NoArgsTool.new] of Fm::Tool)
      tools = session.transcript.entries.first["tools"].as_a
      tools.map(&.["function"]["name"].as_s).should eq(["getServerTime"])
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

  private LONG_PROMPT = "Write a 2000 word essay about the history of the oceans."

  # Runs `block` in its own fiber and returns a channel with its outcome.
  private def in_fiber(&block : -> String) : Channel(String)
    channel = Channel(String).new(1)
    spawn do
      channel.send(begin
        block.call
      rescue ex
        ex.class.name
      end)
    end
    channel
  end

  describe "a blocking request" do
    it "lets other fibers run while it waits" do
      ticks = 0
      waiting = true
      spawn do
        while waiting
          ticks += 1
          sleep 5.milliseconds
        end
      end
      Fm::Session.new(Fm::SystemLanguageModel.new).respond("Say hello.")
      waiting = false
      ticks.should be > 0
    end

    it "is cancelled by Session#cancel from another fiber: stream" do
      session = Fm::Session.new(Fm::SystemLanguageModel.new)
      outcome = in_fiber { session.stream(LONG_PROMPT) { }; "completed" }
      sleep 1.second
      session.cancel
      outcome.receive.should eq("Fm::CancelledError")
    end

    it "is cancelled by Session#cancel from another fiber: stream_json" do
      session = Fm::Session.new(Fm::SystemLanguageModel.new)
      schema = %({"type":"object","properties":{"essay":{"type":"string"}},"required":["essay"]})
      outcome = in_fiber { session.stream_json(LONG_PROMPT, schema) { }; "completed" }
      sleep 1.second
      session.cancel
      outcome.receive.should eq("Fm::CancelledError")
    end

    it "is cancelled by Session#cancel from another fiber: respond" do
      session = Fm::Session.new(Fm::SystemLanguageModel.new)
      outcome = in_fiber { session.respond(LONG_PROMPT); "completed" }
      sleep 1.second
      session.cancel
      outcome.receive.should eq("Fm::CancelledError")
    end
  end

  describe "a string with a null byte" do
    it "is rejected instead of being truncated at the C boundary" do
      model = Fm::SystemLanguageModel.new
      expect_raises(ArgumentError, /prompt.*null byte/) do
        Fm::Session.new(model).respond("Say A.\0Say B.")
      end
      expect_raises(ArgumentError, /instructions.*null byte/) do
        Fm::Session.new(model, instructions: "Be terse.\0Be rude.")
      end
      expect_raises(ArgumentError, /prompt.*null byte/) do
        model.token_count_for("a\0b")
      end
    end
  end
{% end %}
