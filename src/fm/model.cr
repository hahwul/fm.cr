module Fm
  # Represents the availability status of the model.
  enum ModelAvailability
    Available
    DeviceNotEligible
    AppleIntelligenceNotEnabled
    ModelNotReady
    Unknown
  end

  # The intended use case for the model.
  enum UseCase
    # General-purpose language model use (default).
    General
    # Optimized for content tagging and classification.
    ContentTagging
  end

  # Content safety guardrail configuration.
  enum Guardrails
    # Default guardrails applied to all generation.
    Default
    # More permissive guardrails for content transformation tasks
    # (e.g., summarization, rewriting) where the input may contain
    # sensitive content that needs to be preserved in the output.
    PermissiveContentTransformations
  end

  # The system language model provided by Apple Intelligence.
  #
  # This is the main entry point for using on-device AI capabilities.
  #
  # ```
  # model = Fm::SystemLanguageModel.new
  # if model.available?
  #   puts "Model is ready!"
  # end
  # ```
  #
  # You can also specify use case and guardrails:
  #
  # ```
  # model = Fm::SystemLanguageModel.new(
  #   use_case: Fm::UseCase::ContentTagging,
  #   guardrails: Fm::Guardrails::PermissiveContentTransformations
  # )
  # ```
  class SystemLanguageModel
    @ptr : Void*

    def initialize(*, use_case : UseCase = UseCase::General, guardrails : Guardrails = Guardrails::Default)
      error = Fm.make_error_ptr

      @ptr = LibFmFfi.fm_model_create(use_case.value, guardrails.value, error)

      Fm.check_error!(error.value)

      if @ptr.null?
        raise InternalError.new(
          "SystemLanguageModel creation returned null without error. " \
          "FoundationModels.framework may be unavailable."
        )
      end
    end

    # Returns the raw pointer to the underlying Swift object.
    # :nodoc:
    def to_unsafe : Void*
      @ptr
    end

    # Checks if the model is available for use.
    def available? : Bool
      LibFmFfi.fm_model_is_available(@ptr)
    end

    # Gets the current availability status of the model.
    def availability : ModelAvailability
      code = LibFmFfi.fm_model_availability(@ptr)
      case code
      when 0 then ModelAvailability::Available
      when 1 then ModelAvailability::DeviceNotEligible
      when 2 then ModelAvailability::AppleIntelligenceNotEnabled
      when 3 then ModelAvailability::ModelNotReady
      else        ModelAvailability::Unknown
      end
    end

    # Blocks until the model becomes available or the timeout expires.
    # Useful when the model is still downloading (`ModelNotReady`).
    #
    # Raises `TimeoutError` if the model is still not available after
    # the given timeout.
    #
    # ```
    # model = Fm::SystemLanguageModel.new
    # model.wait_until_available(timeout: 60.seconds)
    # puts "Model is ready!"
    # ```
    def wait_until_available(timeout : Time::Span) : Nil
      timeout_ms = timeout.total_milliseconds.to_u64

      error = Fm.make_error_ptr

      LibFmFfi.fm_model_wait_until_available(@ptr, timeout_ms, error)

      Fm.check_error!(error.value)
    end

    # Raises an error if the model is not available.
    def ensure_available! : Nil
      case availability
      when .available?           then nil
      when .device_not_eligible? then raise DeviceNotEligibleError.new
      when .apple_intelligence_not_enabled?
        raise AppleIntelligenceNotEnabledError.new
      when .model_not_ready? then raise ModelNotReadyError.new
      else                        raise ModelNotAvailableError.new("Model is not available")
      end
    end

    # Returns the token usage for a given prompt string.
    #
    # Requires macOS 26.4+ at runtime. Returns `nil` if the API is
    # unavailable on the current OS version.
    #
    # ```
    # if tokens = model.token_usage_for("Hello, world!")
    #   puts "Tokens: #{tokens}"
    # end
    # ```
    def token_usage_for(prompt : String) : Int64?
      error = Fm.make_error_ptr

      result = LibFmFfi.fm_model_token_usage_for(@ptr, prompt.to_unsafe, error)

      Fm.check_error!(error.value)

      result == -2_i64 ? nil : result
    end

    # Returns the token usage for instructions and tools configuration.
    #
    # Requires macOS 26.4+ at runtime. Returns `nil` if the API is
    # unavailable on the current OS version.
    #
    # ```
    # if tokens = model.token_usage_for_tools("Be helpful.", tools_json)
    #   puts "Tokens: #{tokens}"
    # end
    # ```
    def token_usage_for_tools(instructions : String, tools_json : String? = nil) : Int64?
      error = Fm.make_error_ptr

      tools_ptr = tools_json ? tools_json.to_unsafe : Pointer(LibC::Char).null

      result = LibFmFfi.fm_model_token_usage_for_tools(
        @ptr,
        instructions.to_unsafe,
        tools_ptr,
        error
      )

      Fm.check_error!(error.value)

      result == -2_i64 ? nil : result
    end

    def finalize
      unless @ptr.null?
        LibFmFfi.fm_model_free(@ptr)
        @ptr = Pointer(Void).null
      end
    end
  end
end
