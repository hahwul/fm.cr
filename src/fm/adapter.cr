module Fm
  # Represents a model adapter (fine-tuned weights) for customizing
  # the on-device language model's behavior.
  #
  # Adapters can be loaded from a file path or from an app bundle asset.
  #
  # ```
  # # From a file path
  # adapter = Fm::Adapter.new(path: "/path/to/adapter.mlpackage")
  #
  # # From a bundle asset
  # adapter = Fm::Adapter.new(asset: "MyAdapter")
  #
  # # Use with a session
  # session = Fm::Session.new(model, adapters: [adapter])
  # ```
  class Adapter
    # Creates an adapter from a file path.
    def initialize(*, path : String)
      error = Fm.make_error_ptr

      @ptr = LibFmFfi.fm_adapter_create_from_path(path.to_unsafe, error)

      Fm.check_error!(error.value)

      if @ptr.null?
        raise InternalError.new("Adapter creation returned null without error")
      end
    end

    # Creates an adapter from a bundle asset name.
    def initialize(*, asset : String)
      error = Fm.make_error_ptr

      @ptr = LibFmFfi.fm_adapter_create_from_asset(asset.to_unsafe, error)

      Fm.check_error!(error.value)

      if @ptr.null?
        raise InternalError.new("Adapter creation returned null without error")
      end
    end

    # :nodoc:
    def to_unsafe : Void*
      @ptr
    end

    def finalize
      unless @ptr.null?
        LibFmFfi.fm_adapter_free(@ptr)
        @ptr = Pointer(Void).null
      end
    end
  end
end
