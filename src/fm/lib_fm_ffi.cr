lib LibC
  fun strdup(s : LibC::Char*) : LibC::Char*
end

module Fm
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
    fun fm_model_is_available(model : Void*) : Bool
    fun fm_model_availability(model : Void*) : Int32
    fun fm_model_free(model : Void*) : Void

    # Token usage
    fun fm_model_token_usage_for(model : Void*, prompt : LibC::Char*, error_out : Void**) : Int64
    fun fm_model_token_usage_for_tools(model : Void*, instructions : LibC::Char*, tools_json : LibC::Char*, error_out : Void**) : Int64

    # -- Session functions --

    fun fm_session_create(
      model : Void*,
      instructions : LibC::Char*,
      tools_json : LibC::Char*,
      user_data : Void*,
      tool_callback : ToolCallback,
      error_out : Void**,
    ) : Void*

    fun fm_session_from_transcript(
      model : Void*,
      transcript_json : LibC::Char*,
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
