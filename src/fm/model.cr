module Fm
  # Represents the availability status of the model.
  enum ModelAvailability
    Available
    DeviceNotEligible
    AppleIntelligenceNotEnabled
    ModelNotReady
    Unknown
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
  class SystemLanguageModel
    @ptr : Void*

    def initialize
      error = Pointer(Void*).malloc(1)
      error.value = Pointer(Void).null

      @ptr = LibFmFfi.fm_model_default(error)

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

    # Raises an error if the model is not available.
    def ensure_available! : Nil
      case availability
      when .available?             then nil
      when .device_not_eligible?   then raise DeviceNotEligibleError.new
      when .apple_intelligence_not_enabled?
        raise AppleIntelligenceNotEnabledError.new
      when .model_not_ready?       then raise ModelNotReadyError.new
      else                              raise ModelNotAvailableError.new("Model is not available")
      end
    end

    def finalize
      unless @ptr.null?
        LibFmFfi.fm_model_free(@ptr)
        @ptr = Pointer(Void).null
      end
    end
  end
end
