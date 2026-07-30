require "json"

module Fm
  # Represents a session transcript — the complete conversation history
  # including user prompts, model responses, and tool invocations.
  #
  # A `Transcript` wraps the JSON string returned by the Swift FFI layer
  # and provides structured access to entries plus serialization helpers
  # for saving / restoring sessions.
  #
  # ```
  # session = Fm::Session.new(model)
  # session.respond("Hello!")
  #
  # transcript = session.transcript
  # puts transcript.entries.size
  #
  # # Save to disk
  # File.write("session.json", transcript.to_json)
  #
  # # Restore later
  # loaded = Fm::Transcript.from_json(File.read("session.json"))
  # restored = Fm::Session.from_transcript(model, loaded)
  # ```
  struct Transcript
    # The raw JSON string of the transcript.
    getter json : String

    @parsed : JSON::Any? = nil
    @entries : Array(JSON::Any)? = nil

    def initialize(@json : String)
    end

    # Parses the transcript JSON and returns it as `JSON::Any`.
    #
    # Returns a null `JSON::Any` if the JSON is malformed, so dependent
    # accessors such as `entries`/`size` degrade to empty rather than
    # raising. The result is cached for subsequent calls.
    def to_any : JSON::Any
      @parsed ||= begin
        JSON.parse(@json)
      rescue JSON::ParseException
        JSON::Any.new(nil)
      end
    end

    # Returns the transcript entries as an array.
    #
    # Each entry is a `JSON::Any` object with at least a `"role"` field
    # (`"instructions"`, `"user"`, `"response"`, or `"tool"`) and a
    # `"contents"` array.
    #
    # Returns an empty array if the transcript cannot be parsed or has
    # no entries. The result is cached for subsequent calls.
    def entries : Array(JSON::Any)
      @entries ||= begin
        root = to_any.as_h?
        transcript = root.try(&.["transcript"]?).try(&.as_h?)
        if entries = transcript.try(&.["entries"]?)
          entries.as_a? || [] of JSON::Any
        else
          [] of JSON::Any
        end
      end
    end

    # Returns the number of entries in the transcript.
    def size : Int32
      entries.size
    end

    # Returns `true` if the transcript has no entries.
    def empty? : Bool
      entries.empty?
    end

    # Yields each transcript entry to the block.
    def each(& : JSON::Any ->) : Nil
      entries.each { |entry| yield entry }
    end

    # Serializes the transcript to a JSON string.
    def to_json : String
      @json
    end

    # Writes the transcript JSON to an IO.
    def to_json(io : IO) : Nil
      io << @json
    end

    # Writes the transcript into an enclosing JSON document.
    #
    # Without this overload a `Transcript` could not appear inside any larger
    # JSON structure — `{"saved_at" => t, "transcript" => transcript}.to_json`
    # failed to compile, even though the type otherwise presents itself as
    # JSON-serializable.
    #
    # Unlike `#to_json(IO)`, which reproduces the stored text verbatim because
    # it is the whole document, a malformed transcript is written here as JSON
    # `null` — the same degradation `#to_any` applies — so an unparseable
    # transcript cannot corrupt the document it is embedded in.
    def to_json(builder : JSON::Builder) : Nil
      if to_any.raw.nil?
        builder.null
      else
        builder.raw(@json)
      end
    end

    # Creates a `Transcript` from a JSON string.
    def self.from_json(json : String) : self
      new(json)
    end

    # Reads a transcript nested inside an enclosing JSON document, so a type
    # including `JSON::Serializable` can hold a `Transcript` field.
    def self.new(pull : JSON::PullParser) : self
      new(pull.read_raw)
    end
  end
end
