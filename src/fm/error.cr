module Fm
  # Error codes returned by the Swift FFI layer.
  #
  # These map directly to the integer codes from `ffi.swift` and are used
  # by `error_from_swift` / `error_from_stream` to convert raw codes into
  # typed Crystal exceptions.
  enum GenerationErrorCode
    Unknown                    =  0
    ModelNotAvailable          =  1
    Generation                 =  2
    Cancelled                  =  3
    ToolCall                   =  4
    InvalidInput               =  5
    Timeout                    =  6
    ExceededContextWindowSize  =  7
    AssetsUnavailable          =  8
    GuardrailViolation         =  9
    UnsupportedGuide           = 10
    UnsupportedLanguageOrLocale = 11
    DecodingFailure            = 12
    RateLimited                = 13
    ConcurrentRequests         = 14
    Refusal                    = 15
    InvalidGenerationSchema    = 16
  end

  # Base error class for all FoundationModels errors.
  class Error < Exception
  end

  # Model is not available on this device.
  class ModelNotAvailableError < Error
  end

  # Device is not eligible for Apple Intelligence.
  class DeviceNotEligibleError < Error
    def initialize
      super("Device is not eligible for Apple Intelligence")
    end
  end

  # Apple Intelligence is not enabled in system settings.
  class AppleIntelligenceNotEnabledError < Error
    def initialize
      super("Apple Intelligence is not enabled in system settings")
    end
  end

  # Model is not ready (downloading or other system reasons).
  class ModelNotReadyError < Error
    def initialize
      super("Model is not ready (downloading or other system reasons)")
    end
  end

  # Invalid input provided.
  class InvalidInputError < Error
  end

  # Error during generation.
  class GenerationError < Error
  end

  # The operation was cancelled by the caller.
  class CancelledError < Error
  end

  # The input exceeded the model's context window size.
  class ExceededContextWindowSizeError < GenerationError
  end

  # Model assets are unavailable (downloading or missing).
  class AssetsUnavailableError < GenerationError
  end

  # The model refused to generate due to a guardrail violation.
  class GuardrailViolationError < GenerationError
  end

  # A generation guide constraint is not supported.
  class UnsupportedGuideError < GenerationError
  end

  # The requested language or locale is not supported.
  class UnsupportedLanguageOrLocaleError < GenerationError
  end

  # Failed to decode the model's output.
  class DecodingFailureError < GenerationError
  end

  # The request was rate-limited by the system.
  class RateLimitedError < GenerationError
  end

  # Multiple concurrent requests were attempted on the same session.
  class ConcurrentRequestsError < GenerationError
  end

  # The model refused to generate a response.
  class RefusalError < GenerationError
  end

  # The provided generation schema is invalid.
  class InvalidGenerationSchemaError < GenerationError
  end

  # Operation timed out.
  class TimeoutError < Error
  end

  # Error during tool invocation.
  class ToolCallError < Error
    getter tool_name : String
    getter arguments_json : String?

    def initialize(@tool_name : String, message : String, @arguments_json : String? = nil)
      super("Tool '#{@tool_name}' failed: #{message}")
    end
  end

  # Internal FFI error.
  class InternalError < Error
  end

  # :nodoc:
  # Converts a Swift error pointer to a Crystal exception.
  # Frees the Swift error object after extracting information.
  def self.error_from_swift(error_ptr : Void*) : Error
    if error_ptr.null?
      return InternalError.new("FFI error object was null")
    end

    code = LibFmFfi.fm_error_code(error_ptr)
    msg_ptr = LibFmFfi.fm_error_message(error_ptr)

    message = if msg_ptr.null?
                "Error message unavailable"
              else
                String.new(msg_ptr)
              end

    # Extract tool context if this is a tool error
    tool_name_ptr = LibFmFfi.fm_error_tool_name(error_ptr)
    tool_name = tool_name_ptr.null? ? nil : String.new(tool_name_ptr)

    tool_args_ptr = LibFmFfi.fm_error_tool_arguments(error_ptr)
    tool_args = tool_args_ptr.null? ? nil : String.new(tool_args_ptr)

    LibFmFfi.fm_error_free(error_ptr)

    error_code = GenerationErrorCode.from_value?(code)
    return InternalError.new(message) unless error_code

    case error_code
    in .unknown?                           then InternalError.new(message)
    in .model_not_available?              then ModelNotAvailableError.new(message)
    in .generation?                       then GenerationError.new(message)
    in .cancelled?                        then CancelledError.new("Operation cancelled")
    in .tool_call?
      ToolCallError.new(
        tool_name: tool_name || "unknown",
        message: message,
        arguments_json: tool_args
      )
    in .invalid_input?                    then InvalidInputError.new(message)
    in .timeout?                          then TimeoutError.new(message)
    in .exceeded_context_window_size?     then ExceededContextWindowSizeError.new(message)
    in .assets_unavailable?               then AssetsUnavailableError.new(message)
    in .guardrail_violation?              then GuardrailViolationError.new(message)
    in .unsupported_guide?                then UnsupportedGuideError.new(message)
    in .unsupported_language_or_locale?   then UnsupportedLanguageOrLocaleError.new(message)
    in .decoding_failure?                 then DecodingFailureError.new(message)
    in .rate_limited?                     then RateLimitedError.new(message)
    in .concurrent_requests?              then ConcurrentRequestsError.new(message)
    in .refusal?                          then RefusalError.new(message)
    in .invalid_generation_schema?        then InvalidGenerationSchemaError.new(message)
    end
  end

  # :nodoc:
  # Helper to check Swift error output and raise if non-null.
  def self.check_error!(error_ptr : Void*) : Nil
    unless error_ptr.null?
      raise error_from_swift(error_ptr)
    end
  end

  # :nodoc:
  # Converts a streaming error code and message to a typed Crystal exception.
  #
  # Unlike `error_from_swift`, streaming errors only provide a code and
  # message string — there is no FFI error pointer to extract tool context
  # from.
  def self.error_from_stream(code : Int32, message : String) : Error
    error_code = GenerationErrorCode.from_value?(code)
    return GenerationError.new(message) unless error_code

    case error_code
    in .unknown?                          then InternalError.new(message)
    in .model_not_available?              then ModelNotAvailableError.new(message)
    in .generation?                       then GenerationError.new(message)
    in .cancelled?                        then CancelledError.new("Operation cancelled")
    in .tool_call?                        then ToolCallError.new("unknown", message)
    in .invalid_input?                    then InvalidInputError.new(message)
    in .timeout?                          then TimeoutError.new(message)
    in .exceeded_context_window_size?     then ExceededContextWindowSizeError.new(message)
    in .assets_unavailable?               then AssetsUnavailableError.new(message)
    in .guardrail_violation?              then GuardrailViolationError.new(message)
    in .unsupported_guide?                then UnsupportedGuideError.new(message)
    in .unsupported_language_or_locale?   then UnsupportedLanguageOrLocaleError.new(message)
    in .decoding_failure?                 then DecodingFailureError.new(message)
    in .rate_limited?                     then RateLimitedError.new(message)
    in .concurrent_requests?              then ConcurrentRequestsError.new(message)
    in .refusal?                          then RefusalError.new(message)
    in .invalid_generation_schema?        then InvalidGenerationSchemaError.new(message)
    end
  end

  # :nodoc:
  # Allocates an error output pointer for FFI calls.
  def self.make_error_ptr : Pointer(Void*)
    ptr = Pointer(Void*).malloc(1)
    ptr.value = Pointer(Void).null
    ptr
  end
end
