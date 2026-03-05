require "../src/fm"

# Structured output example using Generable

struct Person
  include JSON::Serializable
  include Fm::Generable

  getter name : String
  getter age : Int32
  getter occupation : String
end

model = Fm::SystemLanguageModel.new
model.ensure_available!

session = Fm::Session.new(model)

person = session.respond_structured(Person, "Generate a fictional person who is a software engineer.")
puts "Name: #{person.name}"
puts "Age: #{person.age}"
puts "Occupation: #{person.occupation}"
