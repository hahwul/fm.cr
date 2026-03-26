require "json"

module Fm
  # Sampling strategy for token generation.
  enum Sampling
    # Random sampling with temperature (default).
    Random
    # Greedy sampling: always pick the most likely token.
    Greedy
  end

  # Advanced sampling mode with top-k and top-p (nucleus) parameters.
  #
  # ```
  # mode = Fm::SamplingMode.greedy
  # mode = Fm::SamplingMode.random(top: 40, seed: 42_u64)
  # mode = Fm::SamplingMode.random(probability_threshold: 0.9)
  # ```
  struct SamplingMode
    # The base strategy: Random or Greedy.
    getter strategy : Sampling

    # Top-k: only consider the top `k` most likely tokens (Random only).
    # Cannot be combined with `probability_threshold`.
    getter top : Int32?

    # Top-p (nucleus sampling): only consider tokens whose cumulative
    # probability exceeds this threshold (0.0-1.0, Random only).
    # Cannot be combined with `top`.
    getter probability_threshold : Float64?

    # Seed for reproducible generation (Random only).
    getter seed : UInt64?

    private def initialize(
      @strategy : Sampling,
      @top : Int32? = nil,
      @probability_threshold : Float64? = nil,
      @seed : UInt64? = nil,
    )
    end

    # Greedy (deterministic) sampling: always pick the most likely token.
    def self.greedy : self
      new(strategy: Sampling::Greedy)
    end

    # Random sampling with optional top-k, top-p, and seed.
    #
    # NOTE: `top` and `probability_threshold` cannot both be specified.
    # NOTE: `seed` alone (without `top` or `probability_threshold`) is not
    #   supported by Apple's FoundationModels API and will be ignored.
    def self.random(*, top : Int32? = nil, probability_threshold : Float64? = nil, seed : UInt64? = nil) : self
      if top && probability_threshold
        raise ArgumentError.new("Cannot specify both top (top-k) and probability_threshold (top-p)")
      end
      if t = top
        raise ArgumentError.new("top must be positive, got #{t}") if t <= 0
      end
      if p = probability_threshold
        raise ArgumentError.new("probability_threshold must be between 0.0 and 1.0, got #{p}") unless 0.0 <= p <= 1.0
      end
      new(strategy: Sampling::Random, top: top, probability_threshold: probability_threshold, seed: seed)
    end

    # Creates a SamplingMode from a simple Sampling enum (for backward compatibility).
    def self.from_sampling(sampling : Sampling) : self
      new(strategy: sampling)
    end
  end

  # Options that control how the model generates its response.
  #
  # ```
  # options = Fm::GenerationOptions.new(temperature: 0.7, max_response_tokens: 500_u32)
  # options = Fm::GenerationOptions.new(seed: 42_u64) # reproducible output
  # options = Fm::GenerationOptions.new(sampling_mode: Fm::SamplingMode.random(top: 40))
  # ```
  struct GenerationOptions
    # Temperature for sampling (0.0-2.0). Higher = more random.
    getter temperature : Float64?

    # Sampling strategy (simple enum, for backward compatibility).
    getter sampling : Sampling?

    # Advanced sampling mode with top-k/top-p support.
    getter sampling_mode : SamplingMode?

    # Maximum number of tokens in the response.
    getter max_response_tokens : UInt32?

    # Seed for reproducible generation. When set, the same prompt
    # with the same seed produces deterministic output.
    getter seed : UInt64?

    def initialize(
      @temperature : Float64? = nil,
      @sampling : Sampling? = nil,
      @sampling_mode : SamplingMode? = nil,
      @max_response_tokens : UInt32? = nil,
      @seed : UInt64? = nil,
    )
      if temp = @temperature
        raise ArgumentError.new("temperature must be between 0.0 and 2.0, got #{temp}") unless 0.0 <= temp <= 2.0
      end
    end

    # Returns the default options.
    def self.default : self
      new
    end

    # Returns the effective sampling mode, preferring `sampling_mode` over `sampling`.
    def effective_sampling_mode : SamplingMode?
      @sampling_mode || @sampling.try { |s| SamplingMode.from_sampling(s) }
    end

    # Serializes options to JSON for FFI.
    def to_json : String
      JSON.build do |json|
        json.object do
          if temp = @temperature
            json.field "temperature", temp
          end

          mode = effective_sampling_mode
          if mode
            json.field "sampling" do
              json.object do
                json.field "mode", mode.strategy == Sampling::Greedy ? "greedy" : "random"
                if t = mode.top
                  json.field "top", t
                end
                if p = mode.probability_threshold
                  json.field "probabilityThreshold", p
                end
                if s = mode.seed
                  json.field "seed", s
                end
              end
            end
          end

          if max = @max_response_tokens
            json.field "maximumResponseTokens", max
          end
          # Only emit top-level seed when no sampling_mode carries its own seed,
          # avoiding duplicate "seed" keys in the JSON output.
          if s = @seed
            mode_seed = mode.try(&.seed)
            json.field "seed", s unless mode_seed
          end
        end
      end
    end
  end
end
