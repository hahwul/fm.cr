lib LibC
  fun strdup(s : LibC::Char*) : LibC::Char*
end

module Fm
  # :nodoc:
  # Converts a `Time::Span` timeout into the whole milliseconds the FFI layer
  # expects.
  #
  # `Time::Span#total_milliseconds` is a `Float64`, so a plain `.to_u64` both
  # truncated any sub-millisecond timeout to `0` — which every caller reads as
  # "no timeout", so the call would instead block indefinitely — and raised a
  # bare `OverflowError` for a negative span. Positive spans are rounded *up*
  # so a deliberately tiny timeout still bounds the call, and negatives are
  # rejected with a message that names the offending argument.
  def self.timeout_to_ms(timeout : Time::Span) : UInt64
    if timeout.negative?
      raise ArgumentError.new("timeout must not be negative, got #{timeout}")
    end

    ms = timeout.total_milliseconds
    return 0_u64 if ms == 0

    rounded = ms.ceil
    return UInt64::MAX if rounded >= UInt64::MAX.to_f64
    rounded.to_u64
  end

  # Raw C FFI declarations matching the @_cdecl functions in ext/ffi.swift.
  #
  # Memory management conventions:
  # - Swift objects: opaque Void* pointers, freed via fm_*_free functions
  # - Strings from Swift (strdup): freed via fm_string_free
  # - Strings to Swift: Crystal String is null-terminated, passed directly
  # - Tool callback results: allocated via LibC.strdup, freed by Swift via free()
  @[Link(ldflags: "#{__DIR__}/../../ext/libfm_ffi.a")]
  @[Link(framework: "Foundation")]
  @[Link(framework: "FoundationModels")]
  lib LibFmFfi
    # Callback types
    alias ChunkCallback = (Void*, LibC::Char*) -> Void
    alias DoneCallback = (Void*) -> Void
    alias ErrorCallback = (Void*, Int32, LibC::Char*) -> Void
    alias ToolCallback = (Void*, LibC::Char*, LibC::Char*) -> LibC::Char*

    # -- Error functions --

    fun fm_error_code(error : Void*) : Int32
    fun fm_error_message(error : Void*) : LibC::Char*
    fun fm_error_tool_name(error : Void*) : LibC::Char*
    fun fm_error_tool_arguments(error : Void*) : LibC::Char*
    fun fm_error_free(error : Void*) : Void

    # -- Model functions --

    fun fm_model_default(error_out : Void**) : Void*
    fun fm_model_create(use_case : Int32, guardrails : Int32, error_out : Void**) : Void*
    fun fm_model_is_available(model : Void*) : Bool
    fun fm_model_availability(model : Void*) : Int32
    fun fm_model_wait_until_available(model : Void*, timeout_ms : UInt64, error_out : Void**) : Int32
    fun fm_model_free(model : Void*) : Void

    # Token usage
    fun fm_model_token_usage_for(model : Void*, prompt : LibC::Char*, error_out : Void**) : Int64
    fun fm_model_token_usage_for_tools(model : Void*, instructions : LibC::Char*, tools_json : LibC::Char*, error_out : Void**) : Int64

    # -- Adapter functions --

    fun fm_adapter_create_from_path(path : LibC::Char*, error_out : Void**) : Void*
    fun fm_adapter_create_from_asset(name : LibC::Char*, error_out : Void**) : Void*
    fun fm_adapter_free(adapter : Void*) : Void

    # -- Session functions --

    fun fm_session_create(
      model : Void*,
      instructions : LibC::Char*,
      adapter_ptrs : Void**,
      adapter_count : Int32,
      tools_json : LibC::Char*,
      user_data : Void*,
      tool_callback : ToolCallback,
      error_out : Void**,
    ) : Void*

    fun fm_session_from_transcript(
      model : Void*,
      transcript_json : LibC::Char*,
      instructions : LibC::Char*,
      adapter_ptrs : Void**,
      adapter_count : Int32,
      tools_json : LibC::Char*,
      user_data : Void*,
      tool_callback : ToolCallback,
      error_out : Void**,
    ) : Void*

    fun fm_session_free(session : Void*) : Void

    # Blocking respond
    fun fm_session_respond(
      session : Void*,
      prompt : LibC::Char*,
      options_json : LibC::Char*,
      error_out : Void**,
    ) : LibC::Char*

    fun fm_session_respond_with_timeout(
      session : Void*,
      prompt : LibC::Char*,
      options_json : LibC::Char*,
      timeout_ms : UInt64,
      error_out : Void**,
    ) : LibC::Char*

    # Streaming
    fun fm_session_stream(
      session : Void*,
      prompt : LibC::Char*,
      options_json : LibC::Char*,
      user_data : Void*,
      on_chunk : ChunkCallback,
      on_done : DoneCallback,
      on_error : ErrorCallback,
    ) : Void

    fun fm_session_cancel(session : Void*) : Void
    fun fm_session_is_responding(session : Void*) : Bool

    # Transcript
    fun fm_session_get_transcript(session : Void*, error_out : Void**) : LibC::Char*
    fun fm_session_prewarm(session : Void*, prompt_prefix : LibC::Char*) : Void

    # Generation options
    fun fm_generation_options_create(options_json : LibC::Char*) : Void*
    fun fm_generation_options_free(options : Void*) : Void

    # Structured JSON response
    fun fm_session_respond_json(
      session : Void*,
      prompt : LibC::Char*,
      schema_json : LibC::Char*,
      options_json : LibC::Char*,
      error_out : Void**,
    ) : LibC::Char*

    fun fm_session_stream_json(
      session : Void*,
      prompt : LibC::Char*,
      schema_json : LibC::Char*,
      options_json : LibC::Char*,
      user_data : Void*,
      on_chunk : ChunkCallback,
      on_done : DoneCallback,
      on_error : ErrorCallback,
    ) : Void

    # String management
    fun fm_string_free(s : LibC::Char*) : Void
  end
end
