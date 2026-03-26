require "./spec_helper"

private struct TestPerson
  include JSON::Serializable
  include Fm::Generable

  getter name : String
  getter age : Int32
  getter active : Bool
end

private struct TestWithOptional
  include JSON::Serializable
  include Fm::Generable

  getter name : String
  getter nickname : String?
  getter score : Float64
  getter tags : Array(String)
end

private struct TestNested
  include JSON::Serializable
  include Fm::Generable

  getter person : TestPerson
  getter label : String
end

private struct TestWithJsonField
  include JSON::Serializable
  include Fm::Generable

  @[JSON::Field(key: "full_name")]
  getter name : String

  @[JSON::Field(ignore: true)]
  getter internal_id : Int32 = 0
end

private struct TestWithGuide
  include JSON::Serializable
  include Fm::Generable

  @[Fm::Guide(any_of: ["G", "PG", "PG-13", "R", "NC-17"])]
  getter rating : String

  @[Fm::Guide(minimum: 0, maximum: 10)]
  getter score : Int32

  @[Fm::Guide(pattern: "^[A-Z]")]
  getter title : String

  @[Fm::Guide(min_items: 1, max_items: 5)]
  getter genres : Array(String)

  @[Fm::Guide(count: 3)]
  getter top_three : Array(String)

  @[Fm::Guide(constant: "movie")]
  getter kind : String

  @[Fm::Guide(description: "Release year of the movie")]
  getter year : Int32
end

private enum TestColor
  Red
  Green
  Blue
end

private struct TestWithHash
  include JSON::Serializable
  include Fm::Generable

  getter metadata : Hash(String, String)
end

private struct TestWithEnum
  include JSON::Serializable
  include Fm::Generable

  getter color : TestColor
end

private struct TestWithUnion
  include JSON::Serializable
  include Fm::Generable

  getter value : String | Int32
end

private struct TestWithAllInts
  include JSON::Serializable
  include Fm::Generable

  getter i8 : Int8
  getter i16 : Int16
  getter i64 : Int64
  getter u8 : UInt8
  getter u16 : UInt16
  getter u32 : UInt32
  getter u64 : UInt64
end

private struct TestWithFloat32
  include JSON::Serializable
  include Fm::Generable

  getter score : Float32
end

private struct TestWithDefault
  include JSON::Serializable
  include Fm::Generable

  getter name : String
  getter label : String = "default"
end

private class TestTool < Fm::Tool
  def name : String
    "testTool"
  end

  def description : String
    "A test tool"
  end

  def arguments_schema : JSON::Any
    JSON.parse(%({"type":"object","properties":{"input":{"type":"string"}},"required":["input"]}))
  end

  def call(arguments : JSON::Any) : Fm::ToolOutput
    Fm::ToolOutput.new("result: #{arguments["input"]}")
  end
end

describe Fm do
  it "has a version" do
    Fm::VERSION.should_not be_nil
    Fm::VERSION.should eq "0.3.0"
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

    it "serializes random sampling strategy" do
      opts = Fm::GenerationOptions.new(sampling: Fm::Sampling::Random)
      json = opts.to_json
      json.should contain("random")
    end
  end

  describe Fm::SamplingMode do
    it "creates greedy mode" do
      mode = Fm::SamplingMode.greedy
      mode.strategy.should eq Fm::Sampling::Greedy
      mode.top.should be_nil
      mode.probability_threshold.should be_nil
      mode.seed.should be_nil
    end

    it "creates random mode with defaults" do
      mode = Fm::SamplingMode.random
      mode.strategy.should eq Fm::Sampling::Random
      mode.top.should be_nil
      mode.probability_threshold.should be_nil
      mode.seed.should be_nil
    end

    it "creates random mode with top-k" do
      mode = Fm::SamplingMode.random(top: 40)
      mode.top.should eq 40
      mode.probability_threshold.should be_nil
    end

    it "creates random mode with top-p (probability_threshold)" do
      mode = Fm::SamplingMode.random(probability_threshold: 0.9)
      mode.probability_threshold.should eq 0.9
      mode.top.should be_nil
    end

    it "creates random mode with seed" do
      mode = Fm::SamplingMode.random(seed: 42_u64)
      mode.seed.should eq 42_u64
    end

    it "raises when both top and probability_threshold are specified" do
      expect_raises(ArgumentError, "Cannot specify both top") do
        Fm::SamplingMode.random(top: 40, probability_threshold: 0.9)
      end
    end

    it "creates from Sampling enum" do
      mode = Fm::SamplingMode.from_sampling(Fm::Sampling::Greedy)
      mode.strategy.should eq Fm::Sampling::Greedy
    end
  end

  describe "GenerationOptions with SamplingMode" do
    it "serializes sampling_mode with top-k" do
      mode = Fm::SamplingMode.random(top: 50)
      opts = Fm::GenerationOptions.new(sampling_mode: mode)
      json = opts.to_json
      json.should contain(%("mode":"random"))
      json.should contain(%("top":50))
    end

    it "serializes sampling_mode with top-p" do
      mode = Fm::SamplingMode.random(probability_threshold: 0.85)
      opts = Fm::GenerationOptions.new(sampling_mode: mode)
      json = opts.to_json
      json.should contain(%("mode":"random"))
      json.should contain(%("probabilityThreshold":0.85))
    end

    it "serializes greedy sampling_mode" do
      mode = Fm::SamplingMode.greedy
      opts = Fm::GenerationOptions.new(sampling_mode: mode)
      json = opts.to_json
      json.should contain(%("mode":"greedy"))
    end

    it "serializes sampling_mode with seed" do
      mode = Fm::SamplingMode.random(seed: 123_u64)
      opts = Fm::GenerationOptions.new(sampling_mode: mode)
      json = opts.to_json
      json.should contain(%("seed":123))
    end

    it "prefers sampling_mode over sampling" do
      mode = Fm::SamplingMode.random(top: 10)
      opts = Fm::GenerationOptions.new(sampling: Fm::Sampling::Greedy, sampling_mode: mode)
      opts.effective_sampling_mode.not_nil!.strategy.should eq Fm::Sampling::Random
      opts.effective_sampling_mode.not_nil!.top.should eq 10
    end

    it "falls back to sampling when sampling_mode is nil" do
      opts = Fm::GenerationOptions.new(sampling: Fm::Sampling::Greedy)
      opts.effective_sampling_mode.not_nil!.strategy.should eq Fm::Sampling::Greedy
    end

    it "does not duplicate seed when sampling_mode already carries one" do
      mode = Fm::SamplingMode.random(seed: 42_u64)
      opts = Fm::GenerationOptions.new(sampling_mode: mode, seed: 99_u64)
      json = opts.to_json
      # seed should appear only once (inside the sampling object)
      json.scan(/"seed"/).size.should eq 1
      json.should contain(%("seed":42))
      json.should_not contain(%("seed":99))
    end

    it "emits top-level seed when sampling_mode has no seed" do
      mode = Fm::SamplingMode.random(top: 10)
      opts = Fm::GenerationOptions.new(sampling_mode: mode, seed: 77_u64)
      json = opts.to_json
      json.should contain(%("seed":77))
    end
  end

  describe Fm::Response do
    it "holds content" do
      response = Fm::Response.new("Hello, world!")
      response.content.should eq "Hello, world!"
      response.to_s.should eq "Hello, world!"
    end

    it "writes to IO" do
      response = Fm::Response.new("test output")
      io = IO::Memory.new
      response.to_s(io)
      io.to_s.should eq "test output"
    end
  end

  describe Fm::ToolOutput do
    it "holds string content" do
      output = Fm::ToolOutput.new("result text")
      output.content.should eq "result text"
    end

    it "holds JSON content" do
      json = JSON.parse(%({"key":"value"}))
      output = Fm::ToolOutput.new(json: json)
      output.content.should eq %({"key":"value"})
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

  describe Fm::Tool do
    it "serializes tool definitions to JSON" do
      tools = [TestTool.new] of Fm::Tool
      json = Fm::Tool.tools_to_json(tools)
      parsed = JSON.parse(json)
      parsed.as_a.size.should eq 1
      tool_def = parsed[0]
      tool_def["name"].as_s.should eq "testTool"
      tool_def["description"].as_s.should eq "A test tool"
      schema = tool_def["argumentsSchema"]
      schema["type"].as_s.should eq "object"
      schema["properties"]["input"]["type"].as_s.should eq "string"
    end

    it "invokes tool and returns output" do
      tool = TestTool.new
      args = JSON.parse(%({"input":"hello"}))
      output = tool.call(args)
      output.content.should eq %(result: hello)
    end
  end

  describe "error classes" do
    it "creates ModelNotAvailableError" do
      err = Fm::ModelNotAvailableError.new("custom message")
      err.message.should eq "custom message"
    end

    it "creates DeviceNotEligibleError with default message" do
      err = Fm::DeviceNotEligibleError.new
      err.message.should eq "Device is not eligible for Apple Intelligence"
    end

    it "creates AppleIntelligenceNotEnabledError with default message" do
      err = Fm::AppleIntelligenceNotEnabledError.new
      err.message.should eq "Apple Intelligence is not enabled in system settings"
    end

    it "creates ModelNotReadyError with default message" do
      err = Fm::ModelNotReadyError.new
      err.message.should eq "Model is not ready (downloading or other system reasons)"
    end

    it "creates GenerationError" do
      err = Fm::GenerationError.new("generation failed")
      err.message.should eq "generation failed"
    end

    it "creates TimeoutError" do
      err = Fm::TimeoutError.new("timed out")
      err.message.should eq "timed out"
    end

    it "creates InvalidInputError" do
      err = Fm::InvalidInputError.new("bad input")
      err.message.should eq "bad input"
    end

    it "creates ToolCallError with tool context" do
      err = Fm::ToolCallError.new("myTool", "something broke", %({"arg":"val"}))
      err.tool_name.should eq "myTool"
      err.arguments_json.should eq %({"arg":"val"})
      err.message.should eq "Tool 'myTool' failed: something broke"
    end

    it "creates InternalError" do
      err = Fm::InternalError.new("internal issue")
      err.message.should eq "internal issue"
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

    it "detects over_limit context usage" do
      long_content = "x" * 1000
      json = %([{"role":"user","content":"#{long_content}"}])
      limit = Fm::ContextLimit.new(max_tokens: 10, reserved_response_tokens: 2, chars_per_token: 1)
      usage = Fm.context_usage_from_transcript(json, limit)
      usage.over_limit?.should be_true
      usage.utilization.should be > 1.0
    end

    it "creates ContextLimit with custom values" do
      limit = Fm::ContextLimit.new(max_tokens: 2048, reserved_response_tokens: 256, chars_per_token: 2)
      limit.max_tokens.should eq 2048
      limit.reserved_response_tokens.should eq 256
      limit.chars_per_token.should eq 2
    end

    it "handles transcript_to_text with empty array" do
      text = Fm.transcript_to_text("[]")
      text.should eq "[]"
    end

    it "handles transcript_to_text with nested structure" do
      json = %({"messages":[{"role":"user","content":"Hi"}],"instructions":"Be nice"})
      text = Fm.transcript_to_text(json)
      text.should contain("Be nice")
      text.should contain("user: Hi")
    end

    it "handles transcript_to_text with text field" do
      json = %([{"text":"Plain text entry"}])
      text = Fm.transcript_to_text(json)
      text.should contain("Plain text entry")
    end

    it "estimates tokens with edge cases" do
      Fm.estimate_tokens("a", 1).should eq 1
      Fm.estimate_tokens("abc", 1).should eq 3
      Fm.estimate_tokens("a", 0).should eq 1 # chars_per_token clamped to 1
    end
  end

  describe Fm::CompactionConfig do
    it "has sensible defaults" do
      config = Fm::CompactionConfig.new
      config.chunk_tokens.should eq 800
      config.max_summary_tokens.should eq 400
      config.chars_per_token.should eq 4
      config.instructions.should contain("Summarize")
    end

    it "accepts custom values" do
      opts = Fm::GenerationOptions.new(temperature: 0.5)
      config = Fm::CompactionConfig.new(
        chunk_tokens: 500,
        max_summary_tokens: 200,
        instructions: "Custom instructions",
        summary_options: opts,
        chars_per_token: 2
      )
      config.chunk_tokens.should eq 500
      config.max_summary_tokens.should eq 200
      config.instructions.should eq "Custom instructions"
      config.chars_per_token.should eq 2
    end
  end

  describe Fm::ContextUsage do
    it "computes utilization correctly at boundary" do
      json = %([{"role":"user","content":"Hello"}])
      limit = Fm::ContextLimit.new(max_tokens: 10, reserved_response_tokens: 0, chars_per_token: 4)
      usage = Fm.context_usage_from_transcript(json, limit)
      usage.utilization.should be <= 1.0
      usage.over_limit?.should be_false
    end

    it "handles zero max_tokens" do
      json = %([{"role":"user","content":"Hi"}])
      limit = Fm::ContextLimit.new(max_tokens: 0, reserved_response_tokens: 0)
      usage = Fm.context_usage_from_transcript(json, limit)
      usage.utilization.should eq 0.0_f32
      usage.available_tokens.should eq 0
      usage.over_limit?.should be_true
    end
  end

  describe Fm::Tool do
    it "serializes multiple tools to JSON" do
      tool1 = TestTool.new
      tools = [tool1, tool1] of Fm::Tool
      json = Fm::Tool.tools_to_json(tools)
      parsed = JSON.parse(json)
      parsed.as_a.size.should eq 2
    end
  end

  describe Fm::ToolOutput do
    it "handles empty string content" do
      output = Fm::ToolOutput.new("")
      output.content.should eq ""
    end

    it "handles complex JSON content" do
      json = JSON.parse(%({"items":[1,2,3],"nested":{"key":"val"}}))
      output = Fm::ToolOutput.new(json: json)
      parsed = JSON.parse(output.content)
      parsed["items"].as_a.size.should eq 3
    end
  end

  describe "ModelAvailability enum" do
    it "has all expected values" do
      Fm::ModelAvailability::Available.value.should eq 0
      Fm::ModelAvailability::DeviceNotEligible.value.should eq 1
      Fm::ModelAvailability::AppleIntelligenceNotEnabled.value.should eq 2
      Fm::ModelAvailability::ModelNotReady.value.should eq 3
      Fm::ModelAvailability::Unknown.value.should eq 4
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

    it "handles optional, float, and array types" do
      schema = TestWithOptional.json_schema
      props = schema["properties"].as_h
      props["name"]["type"].as_s.should eq "string"
      props["nickname"]["type"].as_s.should eq "string"
      props["score"]["type"].as_s.should eq "number"
      props["tags"]["type"].as_s.should eq "array"
      props["tags"]["items"]["type"].as_s.should eq "string"

      required = schema["required"].as_a.map(&.as_s)
      required.should contain("name")
      required.should contain("score")
      required.should contain("tags")
      required.should_not contain("nickname")
    end

    it "handles nested Generable types" do
      schema = TestNested.json_schema
      props = schema["properties"].as_h
      props["label"]["type"].as_s.should eq "string"
      person_schema = props["person"]
      person_schema["type"].as_s.should eq "object"
      person_schema["properties"]["name"]["type"].as_s.should eq "string"
    end

    it "respects JSON::Field annotations" do
      schema = TestWithJsonField.json_schema
      props = schema["properties"].as_h
      props.has_key?("full_name").should be_true
      props.has_key?("name").should be_false
      props.has_key?("internal_id").should be_false
    end

    it "applies Guide any_of constraint" do
      schema = TestWithGuide.json_schema
      props = schema["properties"].as_h
      enum_values = props["rating"]["enum"].as_a.map(&.as_s)
      enum_values.should eq ["G", "PG", "PG-13", "R", "NC-17"]
    end

    it "applies Guide minimum/maximum constraints" do
      schema = TestWithGuide.json_schema
      props = schema["properties"].as_h
      props["score"]["minimum"].as_i.should eq 0
      props["score"]["maximum"].as_i.should eq 10
    end

    it "applies Guide pattern constraint" do
      schema = TestWithGuide.json_schema
      props = schema["properties"].as_h
      props["title"]["pattern"].as_s.should eq "^[A-Z]"
    end

    it "applies Guide min_items/max_items constraints" do
      schema = TestWithGuide.json_schema
      props = schema["properties"].as_h
      props["genres"]["minItems"].as_i.should eq 1
      props["genres"]["maxItems"].as_i.should eq 5
    end

    it "applies Guide count constraint" do
      schema = TestWithGuide.json_schema
      props = schema["properties"].as_h
      props["top_three"]["minItems"].as_i.should eq 3
      props["top_three"]["maxItems"].as_i.should eq 3
    end

    it "applies Guide constant constraint" do
      schema = TestWithGuide.json_schema
      props = schema["properties"].as_h
      props["kind"]["const"].as_s.should eq "movie"
    end

    it "applies Guide description" do
      schema = TestWithGuide.json_schema
      props = schema["properties"].as_h
      props["year"]["description"].as_s.should eq "Release year of the movie"
    end
  end

  describe "granular generation errors" do
    it "creates ExceededContextWindowSizeError" do
      err = Fm::ExceededContextWindowSizeError.new("too long")
      err.message.should eq "too long"
      err.is_a?(Fm::GenerationError).should be_true
    end

    it "creates GuardrailViolationError" do
      err = Fm::GuardrailViolationError.new("unsafe content")
      err.message.should eq "unsafe content"
      err.is_a?(Fm::GenerationError).should be_true
    end

    it "creates RateLimitedError" do
      err = Fm::RateLimitedError.new("slow down")
      err.message.should eq "slow down"
      err.is_a?(Fm::GenerationError).should be_true
    end

    it "creates RefusalError" do
      err = Fm::RefusalError.new("refused")
      err.message.should eq "refused"
      err.is_a?(Fm::GenerationError).should be_true
    end

    it "creates ConcurrentRequestsError" do
      err = Fm::ConcurrentRequestsError.new("busy")
      err.message.should eq "busy"
      err.is_a?(Fm::GenerationError).should be_true
    end

    it "creates AssetsUnavailableError" do
      err = Fm::AssetsUnavailableError.new("downloading")
      err.is_a?(Fm::GenerationError).should be_true
    end

    it "creates UnsupportedGuideError" do
      err = Fm::UnsupportedGuideError.new("bad guide")
      err.is_a?(Fm::GenerationError).should be_true
    end

    it "creates UnsupportedLanguageOrLocaleError" do
      err = Fm::UnsupportedLanguageOrLocaleError.new("unsupported")
      err.is_a?(Fm::GenerationError).should be_true
    end

    it "creates DecodingFailureError" do
      err = Fm::DecodingFailureError.new("decode failed")
      err.is_a?(Fm::GenerationError).should be_true
    end

    it "creates InvalidGenerationSchemaError" do
      err = Fm::InvalidGenerationSchemaError.new("bad schema")
      err.is_a?(Fm::GenerationError).should be_true
    end
  end

  describe "UseCase enum" do
    it "has expected values" do
      Fm::UseCase::General.value.should eq 0
      Fm::UseCase::ContentTagging.value.should eq 1
    end
  end

  describe "Guardrails enum" do
    it "has expected values" do
      Fm::Guardrails::Default.value.should eq 0
      Fm::Guardrails::PermissiveContentTransformations.value.should eq 1
    end
  end

  describe "Generable advanced types" do
    it "generates Hash schema with additionalProperties" do
      schema = TestWithHash.json_schema
      props = schema["properties"].as_h
      meta = props["metadata"]
      meta["type"].as_s.should eq "object"
      meta["additionalProperties"]["type"].as_s.should eq "string"
    end

    it "generates Enum schema with string enum values" do
      schema = TestWithEnum.json_schema
      props = schema["properties"].as_h
      color = props["color"]
      color["type"].as_s.should eq "string"
      values = color["enum"].as_a.map(&.as_s)
      values.should eq ["red", "green", "blue"]
    end

    it "generates Union schema with oneOf" do
      schema = TestWithUnion.json_schema
      props = schema["properties"].as_h
      val = props["value"]
      one_of = val["oneOf"].as_a
      one_of.size.should eq 2
      types = one_of.map { |s| s["type"].as_s }
      types.should contain("string")
      types.should contain("integer")
    end

    it "generates integer schema for all integer types" do
      schema = TestWithAllInts.json_schema
      props = schema["properties"].as_h
      %w[i8 i16 i64 u8 u16 u32 u64].each do |field|
        props[field]["type"].as_s.should eq "integer"
      end
    end

    it "generates number schema for Float32" do
      schema = TestWithFloat32.json_schema
      props = schema["properties"].as_h
      props["score"]["type"].as_s.should eq "number"
    end

    it "excludes fields with default values from required" do
      schema = TestWithDefault.json_schema
      required = schema["required"].as_a.map(&.as_s)
      required.should contain("name")
      required.should_not contain("label")
    end

    it "serializes json_schema to valid JSON" do
      schema = TestPerson.json_schema
      json_str = schema.to_json
      parsed = JSON.parse(json_str)
      parsed["type"].as_s.should eq "object"
    end
  end

  describe "error hierarchy" do
    it "all GenerationError subclasses inherit from Error" do
      errors = [
        Fm::ExceededContextWindowSizeError.new("test"),
        Fm::AssetsUnavailableError.new("test"),
        Fm::GuardrailViolationError.new("test"),
        Fm::UnsupportedGuideError.new("test"),
        Fm::UnsupportedLanguageOrLocaleError.new("test"),
        Fm::DecodingFailureError.new("test"),
        Fm::RateLimitedError.new("test"),
        Fm::ConcurrentRequestsError.new("test"),
        Fm::RefusalError.new("test"),
        Fm::InvalidGenerationSchemaError.new("test"),
      ]
      errors.each do |err|
        err.is_a?(Fm::GenerationError).should be_true
        err.is_a?(Fm::Error).should be_true
        err.is_a?(Exception).should be_true
      end
    end

    it "ToolCallError inherits from Error not GenerationError" do
      err = Fm::ToolCallError.new("tool", "msg")
      err.is_a?(Fm::Error).should be_true
      err.is_a?(Fm::GenerationError).should be_false
    end

    it "ToolCallError without arguments_json" do
      err = Fm::ToolCallError.new("myTool", "failed")
      err.tool_name.should eq "myTool"
      err.arguments_json.should be_nil
      err.message.should eq "Tool 'myTool' failed: failed"
    end

    it "TimeoutError inherits from Error not GenerationError" do
      err = Fm::TimeoutError.new("timed out")
      err.is_a?(Fm::Error).should be_true
      err.is_a?(Fm::GenerationError).should be_false
    end

    it "InternalError inherits from Error not GenerationError" do
      err = Fm::InternalError.new("internal")
      err.is_a?(Fm::Error).should be_true
      err.is_a?(Fm::GenerationError).should be_false
    end
  end

  describe "make_error_ptr" do
    it "allocates a null pointer" do
      ptr = Fm.make_error_ptr
      ptr.value.null?.should be_true
    end
  end

  describe "ToolResult JSON serialization" do
    it "success result omits error field" do
      output = Fm::ToolOutput.new("ok")
      result = Fm::ToolResult.success(output)
      json = result.to_json
      parsed = JSON.parse(json)
      parsed["success"].as_bool.should be_true
      parsed["content"].as_s.should eq "ok"
      parsed["error"]?.should be_nil
    end

    it "error result omits content field" do
      result = Fm::ToolResult.error("fail")
      json = result.to_json
      parsed = JSON.parse(json)
      parsed["success"].as_bool.should be_false
      parsed["error"].as_s.should eq "fail"
      parsed["content"]?.should be_nil
    end

    it "ToolResult can be constructed directly" do
      result = Fm::ToolResult.new(success: true, content: "data", error: nil)
      result.success.should be_true
      result.content.should eq "data"
      result.error.should be_nil
    end
  end

  describe "context utilities (advanced)" do
    it "transcript_to_text with prompt and response fields" do
      json = %({"prompt":"What is 2+2?","response":"4"})
      text = Fm.transcript_to_text(json)
      text.should contain("What is 2+2?")
      text.should contain("4")
    end

    it "transcript_to_text with deeply nested messages" do
      json = %({"conversation":{"messages":[{"role":"user","content":"Deep nested"}]}})
      text = Fm.transcript_to_text(json)
      text.should contain("user: Deep nested")
    end

    it "transcript_to_text with role but no content falls back to text fields" do
      json = %([{"role":"system"},{"text":"fallback text"}])
      text = Fm.transcript_to_text(json)
      text.should contain("fallback text")
    end

    it "transcript_to_text returns raw json for non-array non-object primitives" do
      json = %("just a string")
      text = Fm.transcript_to_text(json)
      text.should eq %("just a string")
    end

    it "handles large transcript for context_usage" do
      messages = (1..50).map { |i| %({"role":"user","content":"Message number #{i} with some padding text"}) }
      json = "[#{messages.join(",")}]"
      limit = Fm::ContextLimit.new(max_tokens: 100, reserved_response_tokens: 10, chars_per_token: 4)
      usage = Fm.context_usage_from_transcript(json, limit)
      usage.estimated_tokens.should be > 50
      usage.over_limit?.should be_true
    end

    it "context_usage with all reserved tokens" do
      json = %([{"role":"user","content":"Hi"}])
      limit = Fm::ContextLimit.new(max_tokens: 100, reserved_response_tokens: 100, chars_per_token: 4)
      usage = Fm.context_usage_from_transcript(json, limit)
      usage.available_tokens.should eq 0
      usage.over_limit?.should be_true
    end

    it "context_usage with reserved exceeding max" do
      json = %([{"role":"user","content":"Hi"}])
      limit = Fm::ContextLimit.new(max_tokens: 10, reserved_response_tokens: 20, chars_per_token: 4)
      usage = Fm.context_usage_from_transcript(json, limit)
      usage.available_tokens.should eq 0 # clamped to 0
    end

    it "compacted_instructions with whitespace-only inputs" do
      Fm.compacted_instructions("  ", "  ").should be_nil
      Fm.compacted_instructions("  ", "summary").should eq "Conversation summary:\nsummary"
      Fm.compacted_instructions("base", "  ").should eq "base"
    end

    it "estimate_tokens with single char per token" do
      Fm.estimate_tokens("hello", 1).should eq 5
    end

    it "estimate_tokens with large chars_per_token" do
      Fm.estimate_tokens("hello", 100).should eq 1
    end

    it "ContextUsage can be constructed directly" do
      usage = Fm::ContextUsage.new(
        estimated_tokens: 500_i32,
        max_tokens: 4096_i32,
        reserved_response_tokens: 512_i32,
        available_tokens: 3584_i32,
        utilization: 0.122_f32,
        over_limit: false,
      )
      usage.estimated_tokens.should eq 500
      usage.max_tokens.should eq 4096
      usage.reserved_response_tokens.should eq 512
      usage.available_tokens.should eq 3584
      usage.over_limit?.should be_false
    end
  end

  describe "GenerationOptions (advanced)" do
    it "serializes all parameters together" do
      mode = Fm::SamplingMode.random(top: 20, seed: 55_u64)
      opts = Fm::GenerationOptions.new(
        temperature: 0.9,
        sampling_mode: mode,
        max_response_tokens: 256_u32,
      )
      json = opts.to_json
      json.should contain("0.9")
      json.should contain(%("top":20))
      json.should contain(%("seed":55))
      json.should contain(%("maximumResponseTokens":256))
    end

    it "effective_sampling_mode returns nil when nothing set" do
      opts = Fm::GenerationOptions.default
      opts.effective_sampling_mode.should be_nil
    end

    it "serializes only temperature" do
      opts = Fm::GenerationOptions.new(temperature: 1.5)
      json = opts.to_json
      parsed = JSON.parse(json)
      parsed["temperature"].as_f.should eq 1.5
      parsed["sampling"]?.should be_nil
      parsed["maximumResponseTokens"]?.should be_nil
    end

    it "serializes only max_response_tokens" do
      opts = Fm::GenerationOptions.new(max_response_tokens: 1024_u32)
      json = opts.to_json
      parsed = JSON.parse(json)
      parsed["maximumResponseTokens"].as_i.should eq 1024
      parsed["temperature"]?.should be_nil
    end

    it "serializes random sampling with probability_threshold" do
      mode = Fm::SamplingMode.random(probability_threshold: 0.95)
      opts = Fm::GenerationOptions.new(sampling_mode: mode)
      json = opts.to_json
      json.should contain(%("probabilityThreshold":0.95))
      json.should_not contain(%("top"))
    end
  end

  describe "Response" do
    it "handles empty content" do
      response = Fm::Response.new("")
      response.content.should eq ""
      response.to_s.should eq ""
    end

    it "handles multi-line content" do
      response = Fm::Response.new("line1\nline2\nline3")
      response.content.should eq "line1\nline2\nline3"
      io = IO::Memory.new
      response.to_s(io)
      io.to_s.should eq "line1\nline2\nline3"
    end

    it "handles unicode content" do
      response = Fm::Response.new("안녕하세요 🌍")
      response.content.should eq "안녕하세요 🌍"
    end
  end

  describe "Tool edge cases" do
    it "serializes empty tools array" do
      tools = [] of Fm::Tool
      json = Fm::Tool.tools_to_json(tools)
      parsed = JSON.parse(json)
      parsed.as_a.size.should eq 0
    end

    it "tool call with missing key returns KeyError" do
      tool = TestTool.new
      args = JSON.parse(%({}))
      expect_raises(KeyError) do
        tool.call(args)
      end
    end
  end

  describe "CompactionConfig" do
    it "default summary_options has expected temperature" do
      config = Fm::CompactionConfig.new
      json = config.summary_options.to_json
      json.should contain("0.2")
      json.should contain("256")
    end
  end

  describe "Sampling enum" do
    it "has expected values" do
      Fm::Sampling::Random.value.should eq 0
      Fm::Sampling::Greedy.value.should eq 1
    end
  end

  describe "DEFAULT_CONTEXT_TOKENS" do
    it "equals 4096" do
      Fm::DEFAULT_CONTEXT_TOKENS.should eq 4096
    end
  end

  describe "GenerationOptions validation" do
    it "raises when temperature is negative" do
      expect_raises(ArgumentError, "temperature must be between 0.0 and 2.0") do
        Fm::GenerationOptions.new(temperature: -0.1)
      end
    end

    it "raises when temperature exceeds 2.0" do
      expect_raises(ArgumentError, "temperature must be between 0.0 and 2.0") do
        Fm::GenerationOptions.new(temperature: 2.1)
      end
    end

    it "accepts temperature at boundaries" do
      Fm::GenerationOptions.new(temperature: 0.0).temperature.should eq 0.0
      Fm::GenerationOptions.new(temperature: 2.0).temperature.should eq 2.0
    end

    it "accepts nil temperature" do
      Fm::GenerationOptions.new(temperature: nil).temperature.should be_nil
    end
  end

  describe "SamplingMode validation" do
    it "raises when top is zero" do
      expect_raises(ArgumentError, "top must be positive") do
        Fm::SamplingMode.random(top: 0)
      end
    end

    it "raises when top is negative" do
      expect_raises(ArgumentError, "top must be positive") do
        Fm::SamplingMode.random(top: -1)
      end
    end

    it "raises when probability_threshold is negative" do
      expect_raises(ArgumentError, "probability_threshold must be between 0.0 and 1.0") do
        Fm::SamplingMode.random(probability_threshold: -0.1)
      end
    end

    it "raises when probability_threshold exceeds 1.0" do
      expect_raises(ArgumentError, "probability_threshold must be between 0.0 and 1.0") do
        Fm::SamplingMode.random(probability_threshold: 1.1)
      end
    end

    it "accepts probability_threshold at boundaries" do
      Fm::SamplingMode.random(probability_threshold: 0.0).probability_threshold.should eq 0.0
      Fm::SamplingMode.random(probability_threshold: 1.0).probability_threshold.should eq 1.0
    end

    it "accepts valid top value" do
      Fm::SamplingMode.random(top: 1).top.should eq 1
      Fm::SamplingMode.random(top: 100).top.should eq 100
    end
  end
end
