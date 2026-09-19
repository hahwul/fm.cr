require "json"

module Fm
  # Token usage reported by FoundationModels for one response or a session.
  #
  # Usage is available on macOS 27 and later. On older systems the containing
  # response or session returns `nil` instead.
  struct Usage
    include JSON::Serializable

    @[JSON::Field(key: "inputTokens")]
    getter input_tokens : Int64

    @[JSON::Field(key: "cachedInputTokens")]
    getter cached_input_tokens : Int64

    @[JSON::Field(key: "outputTokens")]
    getter output_tokens : Int64

    @[JSON::Field(key: "reasoningTokens")]
    getter reasoning_tokens : Int64

    @[JSON::Field(key: "totalTokens")]
    getter total_tokens : Int64

    # Model-specific usage metadata, when FoundationModels provides it.
    getter metadata : JSON::Any?

    # A default argument cannot reference another argument, so `total_tokens`
    # is resolved in the body: `nil` means "sum the input and output counts".
    def initialize(
      @input_tokens : Int64,
      @cached_input_tokens : Int64,
      @output_tokens : Int64,
      @reasoning_tokens : Int64,
      total_tokens : Int64? = nil,
      @metadata : JSON::Any? = nil,
    )
      @total_tokens = total_tokens || @input_tokens + @output_tokens
    end
  end

  # Response returned by the model.
  struct Response
    # The text content of the response.
    getter content : String

    # Token usage for this response (macOS 27+).
    getter usage : Usage?

    def initialize(@content : String, @usage : Usage? = nil)
    end

    # Returns `true` if the response content is empty.
    def empty? : Bool
      @content.empty?
    end

    def to_s(io : IO) : Nil
      io << @content
    end

    def to_s : String
      @content
    end
  end
end
