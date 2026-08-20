require "json"

module Fm
  # :nodoc:
  # Rewrites a plain JSON Schema document into the shape
  # `FoundationModels.GenerationSchema` is able to decode.
  #
  # Every guided-generation entry point hands its schema to Swift as JSON, and
  # `ext/ffi.swift` decodes it with `JSONDecoder().decode(GenerationSchema.self,
  # ...)`. That decoder is considerably stricter than JSON Schema:
  #
  # - an object node must carry `title`, `additionalProperties`, `required` and
  #   `x-order` — all four, at every level, not just the root;
  # - `x-order` lists the properties in declaration order and may not name a
  #   property that is missing from `properties`;
  # - a union is spelled `anyOf` (`oneOf` is rejected outright) and needs a
  #   `title` of its own;
  # - `const` only accepts a string.
  #
  # A document missing any of those fails to decode, and the Swift layer then
  # falls back to *asking the model for JSON in the prompt* — dropping the
  # structural guarantee the caller asked for, and, for tools, collapsing every
  # registered tool into a single generic `invoke_tool`. Normalizing here keeps
  # the native guided-generation path alive for `Generable` types and for
  # hand-written schemas alike.
  #
  # The transformation is idempotent: normalizing an already-normalized
  # document leaves it unchanged.
  module Schema
    # Title used for a schema root that does not name itself.
    DEFAULT_TITLE = "Root"

    # Normalizes a parsed schema. Non-object values are returned untouched.
    def self.normalize(schema : JSON::Any, title : String = DEFAULT_TITLE) : JSON::Any
      node = schema.as_h?
      return schema unless node
      JSON::Any.new(normalize_node(node, title))
    end

    # Normalizes a raw JSON schema string.
    #
    # Input that is not parseable JSON is returned unchanged rather than
    # raising: the Swift layer already degrades gracefully on such a schema,
    # and rejecting it here would turn a recoverable case into an exception.
    def self.normalize_json(schema_json : String, title : String = DEFAULT_TITLE) : String
      parsed = begin
        JSON.parse(schema_json)
      rescue JSON::ParseException
        return schema_json
      end

      normalize(parsed, title).to_json
    end

    # :nodoc:
    private def self.normalize_node(node : Hash(String, JSON::Any), title : String) : Hash(String, JSON::Any)
      result = {} of String => JSON::Any
      node.each { |key, value| result[key] = value }

      # `oneOf` is not part of the GenerationSchema vocabulary at all; `anyOf`
      # is the spelling it understands.
      if (one_of = result.delete("oneOf")) && !result.has_key?("anyOf")
        result["anyOf"] = one_of
      end

      if variants = result["anyOf"]?.try(&.as_a?)
        result["anyOf"] = JSON::Any.new(
          variants.map_with_index { |variant, i| normalize(variant, "#{title}Option#{i + 1}") }
        )
        result["title"] = JSON::Any.new(title) unless result["title"]?.try(&.as_s?)
      end

      # A non-string `const` is rejected, so carry it as the single-value `enum`
      # that means the same thing rather than letting it break the document.
      if (const = result["const"]?) && const.as_s?.nil? && !result.has_key?("enum")
        result.delete("const")
        result["enum"] = JSON::Any.new([const])
      end

      if items = result["items"]?
        result["items"] = normalize(items, "#{title}Item")
      end

      if additional = result["additionalProperties"]?.try(&.as_h?)
        result["additionalProperties"] = normalize(JSON::Any.new(additional), "#{title}Value")
      end

      if properties = result["properties"]?.try(&.as_h?)
        normalized = {} of String => JSON::Any
        properties.each { |key, value| normalized[key] = normalize(value, property_title(title, key)) }
        result["properties"] = JSON::Any.new(normalized)

        result["type"] = JSON::Any.new("object") unless result["type"]?.try(&.as_s?)
        result["title"] = JSON::Any.new(title) unless result["title"]?.try(&.as_s?)
        result["additionalProperties"] = JSON::Any.new(false) unless result.has_key?("additionalProperties")
        result["required"] = JSON::Any.new([] of JSON::Any) unless result["required"]?.try(&.as_a?)
        unless result["x-order"]?.try(&.as_a?)
          result["x-order"] = JSON::Any.new(normalized.keys.map { |key| JSON::Any.new(key) })
        end
      end

      result
    end

    # :nodoc:
    # Derives a nested title from the enclosing title and the property name, so
    # every object node ends up with a distinct, stable name.
    private def self.property_title(parent : String, key : String) : String
      camel = key.camelcase
      camel.empty? ? parent : "#{parent}#{camel}"
    end
  end
end
