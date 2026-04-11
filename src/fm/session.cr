require "json"

module Fm
  # A session that interacts with the language model.
  #
  # A session maintains conversation context between requests, enabling
  # multi-turn conversations. Create a new session for each conversation
  # or reuse for multi-turn dialogue.
  #
  # ```
  # model = Fm::SystemLanguageModel.new
  # session = Fm::Session.new(model)
  # response = session.respond("Hello!")
  # puts response.content
  # ```
  class Session
    # Creates a new session with optional instructions, tools, and/or adapters.
    #
    # ```
    # session = Fm::Session.new(model)
    # session = Fm::Session.new(model, instructions: "Be helpful.")
    # session = Fm::Session.new(model, tools: [my_tool])
    # session = Fm::Session.new(model, adapters: [my_adapter])
    # session = Fm::Session.new(model, instructions: "Be helpful.", tools: [my_tool], adapters: [my_adapter])
    # ```
    def initialize(model : SystemLanguageModel, *, instructions : String? = nil, tools : Array(Tool)? = nil, adapters : Array(Adapter)? = nil)
      instructions_ptr = instructions ? instructions.to_unsafe : Pointer(LibC::Char).null
      tools_json, user_data, @tool_box = Session.prepare_tools(tools)
      tools_json_ptr = tools_json ? tools_json.to_unsafe : Pointer(LibC::Char).null
      adapter_ptrs, adapter_count = Session.prepare_adapters(adapters)
      @adapter_ptrs = adapter_ptrs
      @adapters = adapters

      error = Fm.make_error_ptr

      @ptr = LibFmFfi.fm_session_create(
        model.to_unsafe,
        instructions_ptr,
        adapter_ptrs,
        adapter_count,
        tools_json_ptr,
        user_data,
        ->Session.tool_callback(Void*, LibC::Char*, LibC::Char*),
        error
      )

      Fm.check_error!(error.value)

      if @ptr.null?
        raise InternalError.new(
          "Session creation returned null without error. " \
          "Check model availability and instructions validity."
        )
      end
    end

    # :nodoc:
    protected def initialize(@ptr : Void*, @tool_box : Void*?, @adapters : Array(Adapter)? = nil, @adapter_ptrs : Pointer(Void*) = Pointer(Void*).null)
    end

    # Creates a session from a `Transcript` object.
    #
    # Optionally restores instructions, tools, and adapters so the
    # resumed session behaves identically to the original.
    #
    # ```
    # transcript = session.transcript
    # restored = Fm::Session.from_transcript(model, transcript,
    #   instructions: "Be helpful.",
    #   tools: [my_tool],
    #   adapters: [my_adapter],
    # )
    # ```
    def self.from_transcript(
      model : SystemLanguageModel,
      transcript : Transcript,
      *,
      instructions : String? = nil,
      tools : Array(Tool)? = nil,
      adapters : Array(Adapter)? = nil,
    ) : self
      from_transcript(model, transcript.json,
        instructions: instructions,
        tools: tools,
        adapters: adapters,
      )
    end

    # Creates a session from a transcript JSON string.
    #
    # Optionally restores instructions, tools, and adapters so the
    # resumed session behaves identically to the original.
    #
    # ```
    # json = session.transcript_json
    # restored = Fm::Session.from_transcript(model, json,
    #   instructions: "Be helpful.",
    #   tools: [my_tool],
    #   adapters: [my_adapter],
    # )
    # ```
    def self.from_transcript(
      model : SystemLanguageModel,
      transcript_json : String,
      *,
      instructions : String? = nil,
      tools : Array(Tool)? = nil,
      adapters : Array(Adapter)? = nil,
    ) : self
      instructions_ptr = instructions ? instructions.to_unsafe : Pointer(LibC::Char).null
      tools_json, user_data, tool_box = prepare_tools(tools)
      tools_json_ptr = tools_json ? tools_json.to_unsafe : Pointer(LibC::Char).null
      adapter_ptrs, adapter_count = prepare_adapters(adapters)

      error = Fm.make_error_ptr

      ptr = LibFmFfi.fm_session_from_transcript(
        model.to_unsafe,
        transcript_json.to_unsafe,
        instructions_ptr,
        adapter_ptrs,
        adapter_count,
        tools_json_ptr,
        user_data,
        ->Session.tool_callback(Void*, LibC::Char*, LibC::Char*),
        error
      )

      Fm.check_error!(error.value)

      if ptr.null?
        raise InternalError.new(
          "Session creation from transcript returned null without error."
        )
      end

      new(ptr, tool_box, adapters, adapter_ptrs)
    end

    # :nodoc:
    def to_unsafe : Void*
      @ptr
    end

    # Sends a prompt and waits for the complete response.
    #
    # ```
    # response = session.respond("What is the capital of France?")
    # puts response.content
    # ```
    def respond(prompt : String, options : GenerationOptions = GenerationOptions.default) : Response
      error = Fm.make_error_ptr

      response_ptr = LibFmFfi.fm_session_respond(
        @ptr,
        prompt.to_unsafe,
        options.to_json.to_unsafe,
        error
      )

      Response.new(Session.extract_ffi_string!(response_ptr, error))
    end

    # Sends a prompt and waits for the response, with a timeout.
    def respond(prompt : String, options : GenerationOptions = GenerationOptions.default, *, timeout : Time::Span) : Response
      timeout_ms = timeout.total_milliseconds.to_u64

      if timeout_ms == 0
        return respond(prompt, options)
      end

      error = Fm.make_error_ptr

      response_ptr = LibFmFfi.fm_session_respond_with_timeout(
        @ptr,
        prompt.to_unsafe,
        options.to_json.to_unsafe,
        timeout_ms,
        error
      )

      Response.new(Session.extract_ffi_string!(response_ptr, error))
    end

    # Sends a prompt and streams the response via a block.
    #
    # The block receives each text chunk as it arrives from the model.
    # This method blocks until streaming is complete.
    #
    # ```
    # session.stream("Tell me a story") do |chunk|
    #   print chunk
    # end
    # ```
    def stream(prompt : String, options : GenerationOptions = GenerationOptions.default, &block : String ->) : Nil
      state = StreamState.new(block)
      boxed = Box(StreamState).box(state)

      LibFmFfi.fm_session_stream(
        @ptr,
        prompt.to_unsafe,
        options.to_json.to_unsafe,
        boxed,
        ->Session.on_chunk(Void*, LibC::Char*),
        ->Session.on_done(Void*),
        ->Session.on_error(Void*, Int32, LibC::Char*)
      )

      state.raise_if_error!
    end

    # Cancels an ongoing stream operation.
    def cancel : Nil
      LibFmFfi.fm_session_cancel(@ptr)
    end

    # Checks if the session is currently generating a response.
    def responding? : Bool
      LibFmFfi.fm_session_is_responding(@ptr)
    end

    # Returns the session transcript as a `Transcript` object.
    #
    # ```
    # transcript = session.transcript
    # puts transcript.entries.size
    # File.write("session.json", transcript.to_json)
    # ```
    def transcript : Transcript
      Transcript.new(transcript_json)
    end

    # Gets the session transcript as a raw JSON string.
    def transcript_json : String
      error = Fm.make_error_ptr
      ptr = LibFmFfi.fm_session_get_transcript(@ptr, error)
      Fm.check_error!(error.value)
      if ptr.null?
        raise InternalError.new("Transcript retrieval returned null without error")
      end
      content = String.new(ptr)
      LibFmFfi.fm_string_free(ptr)
      content
    end

    # Prewarms the model with an optional prompt prefix.
    def prewarm(prompt_prefix : String? = nil) : Nil
      prefix_ptr = prompt_prefix ? prompt_prefix.to_unsafe : Pointer(LibC::Char).null
      LibFmFfi.fm_session_prewarm(@ptr, prefix_ptr)
    end

    # Sends a prompt and returns a structured JSON response matching a schema.
    #
    # ```
    # schema = %({"type":"object","properties":{"name":{"type":"string"}},"required":["name"]})
    # json = session.respond_json("Generate a person", schema)
    # ```
    def respond_json(prompt : String, schema_json : String, options : GenerationOptions = GenerationOptions.default) : String
      error = Fm.make_error_ptr

      response_ptr = LibFmFfi.fm_session_respond_json(
        @ptr,
        prompt.to_unsafe,
        schema_json.to_unsafe,
        options.to_json.to_unsafe,
        error
      )

      Session.extract_ffi_string!(response_ptr, error, "Received null response from JSON generation")
    end

    # Sends a prompt and returns a deserialized structured response.
    #
    # The type `T` must include `JSON::Serializable` and `Fm::Generable`.
    #
    # ```
    # struct Person
    #   include JSON::Serializable
    #   include Fm::Generable
    #
    #   getter name : String
    #   getter age : Int32
    # end
    #
    # person = session.respond_structured(Person, "Generate a fictional person")
    # puts person.name
    # ```
    def respond_structured(type : T.class, prompt : String, options : GenerationOptions = GenerationOptions.default) : T forall T
      schema = T.json_schema.to_json
      json_str = respond_json(prompt, schema, options)
      T.from_json(json_str)
    end

    # Streams a structured JSON response matching a schema.
    def stream_json(prompt : String, schema_json : String, options : GenerationOptions = GenerationOptions.default, &block : String ->) : Nil
      state = StreamState.new(block)
      boxed = Box(StreamState).box(state)

      LibFmFfi.fm_session_stream_json(
        @ptr,
        prompt.to_unsafe,
        schema_json.to_unsafe,
        options.to_json.to_unsafe,
        boxed,
        ->Session.on_chunk(Void*, LibC::Char*),
        ->Session.on_done(Void*),
        ->Session.on_error(Void*, Int32, LibC::Char*)
      )

      state.raise_if_error!
    end

    def finalize
      unless @ptr.null?
        LibFmFfi.fm_session_free(@ptr)
        @ptr = Pointer(Void).null
      end
      @adapter_ptrs = Pointer(Void*).null
    end

    # -- Helper methods --

    # :nodoc:
    # Extracts a String from an FFI char pointer, checking for errors and freeing memory.
    protected def self.extract_ffi_string!(ptr : LibC::Char*, error : Pointer(Void*), null_message : String = "Received null response") : String
      Fm.check_error!(error.value)

      if ptr.null?
        raise GenerationError.new(null_message)
      end

      content = String.new(ptr)
      LibFmFfi.fm_string_free(ptr)
      content
    end

    # :nodoc:
    # Prepares tool JSON and boxing for FFI calls.
    # Returns the JSON String (to keep it alive for GC safety), user_data pointer, and tool_box.
    protected def self.prepare_tools(tools : Array(Tool)?) : {String?, Void*, Void*?}
      if tools && !tools.empty?
        tools_json = Tool.tools_to_json(tools)
        boxed = Box(Array(Tool)).box(tools)
        {tools_json, boxed, boxed}
      else
        {nil, Pointer(Void).null, nil}
      end
    end

    # :nodoc:
    # Prepares adapter pointers for FFI calls.
    protected def self.prepare_adapters(adapters : Array(Adapter)?) : {Pointer(Void*), Int32}
      if adapters && !adapters.empty?
        count = adapters.size.to_i32
        ptrs = Pointer(Void*).malloc(count)
        adapters.each_with_index do |adapter, i|
          ptrs[i] = adapter.to_unsafe
        end
        {ptrs, count}
      else
        {Pointer(Void*).null, 0_i32}
      end
    end

    # -- Streaming callback infrastructure --

    # :nodoc:
    class StreamState
      property error : String?
      property error_code : Int32 = 0
      getter on_chunk : String ->

      def initialize(@on_chunk : String ->)
        @error = nil
      end

      # Raises the appropriate error if one was recorded during streaming.
      def raise_if_error! : Nil
        if err = @error
          raise Fm.error_from_stream(@error_code, err)
        end
      end
    end

    # :nodoc:
    protected def self.on_chunk(user_data : Void*, chunk : LibC::Char*) : Void
      return if user_data.null? || chunk.null?
      state = Box(StreamState).unbox(user_data)
      state.on_chunk.call(String.new(chunk))
    end

    # :nodoc:
    protected def self.on_done(user_data : Void*) : Void
    end

    # :nodoc:
    protected def self.on_error(user_data : Void*, code : Int32, message : LibC::Char*) : Void
      return if user_data.null?
      state = Box(StreamState).unbox(user_data)
      msg = message.null? ? "Streaming error (no message)" : String.new(message)
      state.error = msg
      state.error_code = code
    end

    # -- Tool callback --

    # :nodoc:
    protected def self.tool_callback(user_data : Void*, tool_name : LibC::Char*, arguments_json : LibC::Char*) : LibC::Char*
      if user_data.null? || tool_name.null?
        result = ToolResult.error("Invalid callback parameters")
        return LibC.strdup(result.to_json)
      end

      tools = Box(Array(Tool)).unbox(user_data)
      name = String.new(tool_name)
      args_str = arguments_json.null? ? "{}" : String.new(arguments_json)

      tool = tools.find { |t| t.name == name }
      unless tool
        result = ToolResult.error("Unknown tool: #{name}")
        return LibC.strdup(result.to_json)
      end

      result = begin
        args = JSON.parse(args_str)
        output = tool.call(args)
        ToolResult.success(output)
      rescue ex
        ToolResult.error(ex.message || "Tool invocation failed")
      end

      LibC.strdup(result.to_json)
    end
  end
end
