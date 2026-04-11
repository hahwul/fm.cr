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
    # The result is cached for subsequent calls.
    def to_any : JSON::Any
      @parsed ||= JSON.parse(@json)
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
        parsed = to_any
        if transcript = parsed["transcript"]?
          if entries = transcript["entries"]?
            entries.as_a
          else
            [] of JSON::Any
          end
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

    # Creates a `Transcript` from a JSON string.
    def self.from_json(json : String) : self
      new(json)
    end
  end
end
