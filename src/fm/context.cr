require "json"

module Fm
  # Default context window size for Apple's on-device Foundation Models.
  DEFAULT_CONTEXT_TOKENS = 4096

  # Configuration for estimating context usage.
  struct ContextLimit
    # Maximum tokens available in the session context window.
    getter max_tokens : Int32

    # Tokens reserved for the model's next response.
    getter reserved_response_tokens : Int32

    # Estimated characters per token (English ~3-4, CJK ~1).
    getter chars_per_token : Int32

    def initialize(
      @max_tokens : Int32 = DEFAULT_CONTEXT_TOKENS,
      @reserved_response_tokens : Int32 = 0,
      @chars_per_token : Int32 = 4,
    )
    end

    # Creates a default configuration for on-device models.
    def self.default_on_device : self
      new(
        max_tokens: DEFAULT_CONTEXT_TOKENS,
        reserved_response_tokens: 512,
        chars_per_token: 4
      )
    end
  end

  # Estimated context usage for a session.
  struct ContextUsage
    # Estimated number of tokens consumed by the transcript.
    getter estimated_tokens : Int32

    # Maximum tokens configured for the session.
    getter max_tokens : Int32

    # Tokens reserved for the next response.
    getter reserved_response_tokens : Int32

    # Estimated tokens available before hitting the limit.
    getter available_tokens : Int32

    # Estimated utilization ratio (0.0 - 1.0+).
    getter utilization : Float32

    # Whether the estimate exceeds the available budget.
    getter? over_limit : Bool

    def initialize(
      @estimated_tokens : Int32,
      @max_tokens : Int32,
      @reserved_response_tokens : Int32,
      @available_tokens : Int32,
      @utilization : Float32,
      @over_limit : Bool,
    )
    end
  end

  # Estimates token usage from transcript JSON and a context limit.
  def self.context_usage_from_transcript(transcript_json : String, limit : ContextLimit) : ContextUsage
    transcript_text = transcript_to_text(transcript_json)
    estimated_tokens = estimate_tokens(transcript_text, limit.chars_per_token)
    available_tokens = {limit.max_tokens - limit.reserved_response_tokens, 0}.max
    utilization = limit.max_tokens > 0 ? estimated_tokens.to_f32 / limit.max_tokens : 0.0_f32
    over_limit = estimated_tokens > available_tokens

    ContextUsage.new(
      estimated_tokens: estimated_tokens,
      max_tokens: limit.max_tokens,
      reserved_response_tokens: limit.reserved_response_tokens,
      available_tokens: available_tokens,
      utilization: utilization,
      over_limit: over_limit
    )
  end

  # Estimates tokens based on a characters-per-token heuristic.
  def self.estimate_tokens(text : String, chars_per_token : Int32) : Int32
    denom = {chars_per_token, 1}.max
    chars = text.size
    ((chars + denom - 1) // denom).to_i32
  end

  # Extracts readable text from transcript JSON.
  def self.transcript_to_text(transcript_json : String) : String
    value = JSON.parse(transcript_json)
    lines = [] of String
    collect_transcript_lines(value, lines)
    lines.empty? ? transcript_json : lines.join("\n")
  end

  # Configuration for transcript compaction.
  struct CompactionConfig
    getter chunk_tokens : Int32
    getter max_summary_tokens : Int32
    getter instructions : String
    getter summary_options : GenerationOptions
    getter chars_per_token : Int32

    def initialize(
      @chunk_tokens : Int32 = 800,
      @max_summary_tokens : Int32 = 400,
      @instructions : String = "Summarize the conversation for future context. Preserve user intent, key facts, decisions, and open questions. Keep the summary concise.",
      @summary_options : GenerationOptions = GenerationOptions.new(temperature: 0.2, max_response_tokens: 256_u32),
      @chars_per_token : Int32 = 4,
    )
    end
  end

  # Result of compacting a session.
  struct CompactedSession
    getter session : Session
    getter summary : String

    def initialize(@session : Session, @summary : String)
    end
  end

  # Compacts a transcript into a summary using the on-device model.
  def self.compact_transcript(
    model : SystemLanguageModel,
    transcript_json : String,
    config : CompactionConfig = CompactionConfig.new,
  ) : String
    transcript_text = transcript_to_text(transcript_json)
    return "" if transcript_text.strip.empty?

    chunks = chunk_text(transcript_text, config.chunk_tokens, config.chars_per_token)
    summary = ""

    chunks.each do |chunk|
      session = Session.new(model, instructions: config.instructions)
      prompt = build_summary_prompt(summary, chunk, config.max_summary_tokens, config.chars_per_token)
      response = session.respond(prompt, config.summary_options)
      summary = response.content
    end

    summary
  end

  # Compacts a session if context usage exceeds the limit.
  # Returns nil if still within budget.
  def self.compact_session_if_needed(
    model : SystemLanguageModel,
    session : Session,
    limit : ContextLimit,
    config : CompactionConfig = CompactionConfig.new,
    base_instructions : String? = nil,
  ) : CompactedSession?
    transcript_json = session.transcript_json
    usage = context_usage_from_transcript(transcript_json, limit)
    return nil unless usage.over_limit?

    summary = compact_transcript(model, transcript_json, config)
    compacted = session_from_summary(model, base_instructions, summary)
    CompactedSession.new(session: compacted, summary: summary)
  end

  # Creates a new session from base instructions and a summary.
  def self.session_from_summary(
    model : SystemLanguageModel,
    base_instructions : String?,
    summary : String,
  ) : Session
    instructions = compacted_instructions(base_instructions, summary)
    if instructions
      Session.new(model, instructions: instructions)
    else
      Session.new(model)
    end
  end

  # Builds instructions text for a compacted session.
  def self.compacted_instructions(base_instructions : String?, summary : String) : String?
    base = base_instructions.try(&.strip) || ""
    stripped_summary = summary.strip

    if base.empty? && stripped_summary.empty?
      nil
    elsif !base.empty? && stripped_summary.empty?
      base
    elsif base.empty? && !stripped_summary.empty?
      "Conversation summary:\n#{stripped_summary}"
    else
      "#{base}\n\nConversation summary:\n#{stripped_summary}"
    end
  end

  TRANSCRIPT_TEXT_KEYS = {"content", "text", "prompt", "response", "instructions"}
  TRANSCRIPT_SKIP_KEYS = {"role", "content", "text", "prompt", "response", "instructions"}

  # :nodoc:
  private def self.collect_transcript_lines(value : JSON::Any, out lines : Array(String))
    case value.raw
    when Array
      value.as_a.each { |item| collect_transcript_lines(item, lines) }
    when Hash
      map = value.as_h
      processed_content = false

      if role = map["role"]?.try(&.as_s?)
        content = map["content"]?.try(&.as_s?) || map["text"]?.try(&.as_s?)
        if content
          lines << "#{role}: #{content}"
          processed_content = true
        end
      end

      TRANSCRIPT_TEXT_KEYS.each do |key|
        next if processed_content && (key == "content" || key == "text")
        if text = map[key]?.try(&.as_s?)
          lines << text
        end
      end

      map.each do |key, val|
        next if TRANSCRIPT_SKIP_KEYS.includes?(key)
        collect_transcript_lines(val, lines)
      end
    end
  end

  # :nodoc:
  private def self.chunk_text(text : String, chunk_tokens : Int32, chars_per_token : Int32) : Array(String)
    max_bytes = {chunk_tokens, 1}.max * {chars_per_token, 1}.max
    chunks = [] of String
    current = String::Builder.new

    text.each_line do |line|
      line_bytes = line.bytesize + 1
      if current.bytesize > 0 && current.bytesize + line_bytes > max_bytes
        chunks << current.to_s.rstrip
        current = String::Builder.new
      end
      current << line << '\n'
    end

    result = current.to_s.strip
    chunks << result unless result.empty?
    chunks << text if chunks.empty?
    chunks
  end

  # :nodoc:
  private def self.build_summary_prompt(
    current_summary : String,
    chunk : String,
    max_summary_tokens : Int32,
    chars_per_token : Int32,
  ) : String
    if current_summary.strip.empty?
      "Summarize the following conversation transcript:\n\n#{chunk}\n\nReturn a concise summary."
    else
      summary_tokens = estimate_tokens(current_summary, chars_per_token)
      truncated = if summary_tokens > max_summary_tokens
                    max_chars = max_summary_tokens * {chars_per_token, 1}.max
                    if current_summary.size > max_chars
                      "..#{current_summary[current_summary.size - max_chars..]}"
                    else
                      current_summary
                    end
                  else
                    current_summary
                  end

      "Update the summary with new conversation content.\n\nCurrent summary:\n#{truncated}\n\nNew transcript chunk:\n#{chunk}\n\nReturn the updated concise summary."
    end
  end
end
