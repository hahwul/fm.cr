require "./spec_helper"

private struct TestPerson
  include JSON::Serializable
  include Fm::Generable

  getter name : String
  getter age : Int32
  getter active : Bool
end

describe Fm do
  it "has a version" do
    Fm::VERSION.should_not be_nil
    Fm::VERSION.should eq "0.1.0"
  end

  describe Fm::GenerationOptions do
    it "creates default options" do
      opts = Fm::GenerationOptions.default
      opts.temperature.should be_nil
      opts.sampling.should be_nil
      opts.max_response_tokens.should be_nil
    end

    it "creates options with parameters" do
      opts = Fm::GenerationOptions.new(temperature: 0.7, max_response_tokens: 500_u32)
      opts.temperature.should eq 0.7
      opts.max_response_tokens.should eq 500_u32
    end

    it "serializes to JSON" do
      opts = Fm::GenerationOptions.new(temperature: 0.7, max_response_tokens: 100_u32)
      json = opts.to_json
      json.should contain("temperature")
      json.should contain("0.7")
      json.should contain("maximumResponseTokens")
      json.should contain("100")
    end

    it "serializes empty options" do
      opts = Fm::GenerationOptions.default
      json = opts.to_json
      json.should eq("{}")
    end

    it "serializes sampling strategy" do
      opts = Fm::GenerationOptions.new(sampling: Fm::Sampling::Greedy)
      json = opts.to_json
      json.should contain("greedy")
    end
  end

  describe Fm::Response do
    it "holds content" do
      response = Fm::Response.new("Hello, world!")
      response.content.should eq "Hello, world!"
      response.to_s.should eq "Hello, world!"
    end
  end

  describe Fm::ToolOutput do
    it "holds string content" do
      output = Fm::ToolOutput.new("result text")
      output.content.should eq "result text"
    end
  end

  describe Fm::ToolResult do
    it "creates success result" do
      output = Fm::ToolOutput.new("OK")
      result = Fm::ToolResult.success(output)
      result.success.should be_true
      result.content.should eq "OK"
      json = result.to_json
      json.should contain(%("success":true))
      json.should contain(%("content":"OK"))
    end

    it "creates error result" do
      result = Fm::ToolResult.error("something went wrong")
      result.success.should be_false
      result.error.should eq "something went wrong"
      json = result.to_json
      json.should contain(%("success":false))
      json.should contain(%("error":"something went wrong"))
    end
  end

  describe "context utilities" do
    it "estimates tokens" do
      Fm.estimate_tokens("abcd", 4).should eq 1
      Fm.estimate_tokens("abcde", 4).should eq 2
      Fm.estimate_tokens("", 4).should eq 0
    end

    it "creates default ContextLimit" do
      limit = Fm::ContextLimit.default_on_device
      limit.max_tokens.should eq 4096
      limit.reserved_response_tokens.should eq 512
      limit.chars_per_token.should eq 4
    end

    it "computes compacted_instructions" do
      Fm.compacted_instructions(nil, "").should be_nil
      Fm.compacted_instructions("You are helpful.", "").should eq "You are helpful."
      Fm.compacted_instructions(nil, "Summary body").should eq "Conversation summary:\nSummary body"
      Fm.compacted_instructions("You are helpful.", "Summary body").should eq "You are helpful.\n\nConversation summary:\nSummary body"
    end

    it "extracts transcript text" do
      json = %([{"role":"user","content":"Hello"},{"role":"assistant","content":"Hi there"}])
      text = Fm.transcript_to_text(json)
      text.should contain("user: Hello")
      text.should contain("assistant: Hi there")
    end

    it "computes context usage from transcript" do
      json = %([{"role":"user","content":"Hello world"}])
      limit = Fm::ContextLimit.new(max_tokens: 100, reserved_response_tokens: 20)
      usage = Fm.context_usage_from_transcript(json, limit)
      usage.max_tokens.should eq 100
      usage.reserved_response_tokens.should eq 20
      usage.available_tokens.should eq 80
      usage.over_limit?.should be_false
    end
  end

  describe Fm::Generable do
    it "generates JSON schema" do
      schema = TestPerson.json_schema
      schema["type"].as_s.should eq "object"
      props = schema["properties"].as_h
      props["name"]["type"].as_s.should eq "string"
      props["age"]["type"].as_s.should eq "integer"
      props["active"]["type"].as_s.should eq "boolean"
      required = schema["required"].as_a.map(&.as_s)
      required.should contain("name")
      required.should contain("age")
      required.should contain("active")
    end
  end
end
