module Fm
  # Annotation for adding generation constraints to `Generable` fields.
  #
  # These constraints map to JSON Schema validation keywords and are used
  # by the on-device model to enforce output structure during guided generation.
  #
  # ```
  # struct Movie
  #   include JSON::Serializable
  #   include Fm::Generable
  #
  #   getter title : String
  #
  #   @[Fm::Guide(any_of: ["G", "PG", "PG-13", "R", "NC-17"])]
  #   getter rating : String
  #
  #   @[Fm::Guide(minimum: 0, maximum: 10)]
  #   getter score : Int32
  #
  #   @[Fm::Guide(pattern: "^[A-Z]")]
  #   getter director : String
  #
  #   @[Fm::Guide(min_items: 1, max_items: 5)]
  #   getter genres : Array(String)
  # end
  # ```
  #
  # Supported constraints:
  # - `any_of` : Restrict string values to a set of choices (JSON Schema "enum")
  # - `constant` : Fix a field to a single constant value (JSON Schema "const")
  # - `minimum` : Minimum numeric value (JSON Schema "minimum")
  # - `maximum` : Maximum numeric value (JSON Schema "maximum")
  # - `pattern` : Regex pattern for string values (JSON Schema "pattern")
  # - `min_items` : Minimum array length (JSON Schema "minItems")
  # - `max_items` : Maximum array length (JSON Schema "maxItems")
  # - `count` : Exact array length (sets both minItems and maxItems)
  # - `description` : Human-readable field description (JSON Schema "description")
  #
  # Several `Fm::Guide` annotations may be stacked on one field; all of them are
  # applied, and if two set the same option the last one wins.
  #
  # ```
  # @[Fm::Guide(description: "Log level setting")]
  # @[Fm::Guide(any_of: ["debug", "info", "warn", "error"])]
  # getter log_level : String
  # ```
  annotation Guide
  end
end
