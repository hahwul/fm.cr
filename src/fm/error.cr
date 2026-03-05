module Fm
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

    case code
    when 1 then ModelNotAvailableError.new(message)
    when 2 then GenerationError.new(message)
    when 3 then GenerationError.new("Operation cancelled")
    when 4
      ToolCallError.new(
        tool_name: tool_name || "unknown",
        message: message,
        arguments_json: tool_args
      )
    when  5 then InvalidInputError.new(message)
    when  6 then TimeoutError.new(message)
    when  7 then ExceededContextWindowSizeError.new(message)
    when  8 then AssetsUnavailableError.new(message)
    when  9 then GuardrailViolationError.new(message)
    when 10 then UnsupportedGuideError.new(message)
    when 11 then UnsupportedLanguageOrLocaleError.new(message)
    when 12 then DecodingFailureError.new(message)
    when 13 then RateLimitedError.new(message)
    when 14 then ConcurrentRequestsError.new(message)
    when 15 then RefusalError.new(message)
    when 16 then InvalidGenerationSchemaError.new(message)
    else         InternalError.new(message)
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
  # Allocates an error output pointer for FFI calls.
  def self.make_error_ptr : Pointer(Void*)
    ptr = Pointer(Void*).malloc(1)
    ptr.value = Pointer(Void).null
    ptr
  end
end
