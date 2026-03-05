require "../src/fm"

# Context management example: estimate usage and compact when needed

model = Fm::SystemLanguageModel.new
model.ensure_available!

session = Fm::Session.new(model, instructions: "You are a helpful assistant.")

# Have a conversation
session.respond("What is Crystal?")
session.respond("How does it compare to Ruby?")

# Check context usage
transcript = session.transcript_json
limit = Fm::ContextLimit.default_on_device
usage = Fm.context_usage_from_transcript(transcript, limit)

puts "Estimated tokens: #{usage.estimated_tokens}"
puts "Max tokens: #{usage.max_tokens}"
puts "Available: #{usage.available_tokens}"
puts "Utilization: #{(usage.utilization * 100).round(1)}%"
puts "Over limit: #{usage.over_limit?}"

# Compact if needed
result = Fm.compact_session_if_needed(model, session, limit, base_instructions: "You are a helpful assistant.")
if result
  puts "\nSession compacted!"
  puts "Summary: #{result.summary}"
else
  puts "\nNo compaction needed."
end
