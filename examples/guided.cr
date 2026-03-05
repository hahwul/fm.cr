require "../src/fm"

# Guided generation example using Fm::Guide annotations.
# Demonstrates constraining structured output fields with
# enum values, numeric ranges, regex patterns, and array limits.

struct MovieReview
  include JSON::Serializable
  include Fm::Generable

  @[Fm::Guide(pattern: "^[A-Z]")]
  getter title : String

  @[Fm::Guide(any_of: ["G", "PG", "PG-13", "R", "NC-17"])]
  getter rating : String

  @[Fm::Guide(minimum: 1, maximum: 10)]
  getter score : Int32

  @[Fm::Guide(min_items: 1, max_items: 3)]
  getter genres : Array(String)

  @[Fm::Guide(description: "Brief one-sentence summary of the movie")]
  getter summary : String
end

# Print the generated schema to see constraints
puts "Generated JSON Schema:"
puts MovieReview.json_schema.to_pretty_json
puts

model = Fm::SystemLanguageModel.new
model.ensure_available!

session = Fm::Session.new(model, instructions: "You are a movie critic.")

review = session.respond_structured(
  MovieReview,
  "Write a review for a science fiction movie."
)

puts "Title: #{review.title}"
puts "Rating: #{review.rating}"
puts "Score: #{review.score}/10"
puts "Genres: #{review.genres.join(", ")}"
puts "Summary: #{review.summary}"
