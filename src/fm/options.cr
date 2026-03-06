require "json"

module Fm
  # Sampling strategy for token generation.
  enum Sampling
    # Random sampling with temperature (default).
    Random
    # Greedy sampling: always pick the most likely token.
    Greedy
  end

  # Options that control how the model generates its response.
  #
  # ```
  # options = Fm::GenerationOptions.new(temperature: 0.7, max_response_tokens: 500_u32)
  # options = Fm::GenerationOptions.new(seed: 42_u64) # reproducible output
  # ```
  struct GenerationOptions
    # Temperature for sampling (0.0-2.0). Higher = more random.
    getter temperature : Float64?

    # Sampling strategy.
    getter sampling : Sampling?

    # Maximum number of tokens in the response.
    getter max_response_tokens : UInt32?

    # Seed for reproducible generation. When set, the same prompt
    # with the same seed produces deterministic output.
    getter seed : UInt64?

    def initialize(
      @temperature : Float64? = nil,
      @sampling : Sampling? = nil,
      @max_response_tokens : UInt32? = nil,
      @seed : UInt64? = nil,
    )
    end

    # Returns the default options.
    def self.default : self
      new
    end

    # Serializes options to JSON for FFI.
    def to_json : String
      JSON.build do |json|
        json.object do
          if temp = @temperature
            json.field "temperature", temp
          end
          if s = @sampling
            json.field "sampling", s == Sampling::Greedy ? "greedy" : "random"
          end
          if max = @max_response_tokens
            json.field "maximumResponseTokens", max
          end
          if s = @seed
            json.field "seed", s
          end
        end
      end
    end
  end
end
