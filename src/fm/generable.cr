require "json"

module Fm
  # Include this module in a struct/class to auto-generate JSON Schema
  # for structured output with `Session#respond_structured`.
  #
  # The type must also include `JSON::Serializable`.
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
  # schema = Person.json_schema
  # # => {"type" => "object", "properties" => {"name" => {"type" => "string"}, ...}, "required" => [...]}
  # ```
  module Generable
    macro included
      def self.json_schema : JSON::Any
        properties = JSON::Any.new({} of String => JSON::Any)
        required = [] of JSON::Any

        \{% for ivar in @type.instance_vars %}
          \{% ann = ivar.annotation(JSON::Field) %}
          \{% key = ann && ann[:key] ? ann[:key] : ivar.name.stringify %}
          \{% unless ann && ann[:ignore] %}
            properties.as_h[\{{key}}] = Fm::Generable.type_to_schema(\{{ivar.type}})
            \{% unless ivar.type.nilable? || ivar.has_default_value? %}
              required << JSON::Any.new(\{{key}})
            \{% end %}
          \{% end %}
        \{% end %}

        schema = {
          "type"       => JSON::Any.new("object"),
          "properties" => properties,
        } of String => JSON::Any

        unless required.empty?
          schema["required"] = JSON::Any.new(required)
        end

        JSON::Any.new(schema)
      end
    end

    # Maps Crystal types to JSON Schema type descriptors.
    def self.type_to_schema(type : T.class) : JSON::Any forall T
      {% if T == String %}
        JSON::Any.new({"type" => JSON::Any.new("string")} of String => JSON::Any)
      {% elsif T == Int32 || T == Int64 || T == Int16 || T == Int8 || T == UInt32 || T == UInt64 || T == UInt16 || T == UInt8 %}
        JSON::Any.new({"type" => JSON::Any.new("integer")} of String => JSON::Any)
      {% elsif T == Float32 || T == Float64 %}
        JSON::Any.new({"type" => JSON::Any.new("number")} of String => JSON::Any)
      {% elsif T == Bool %}
        JSON::Any.new({"type" => JSON::Any.new("boolean")} of String => JSON::Any)
      {% elsif T.nilable? %}
        {% non_nil = T.union_types.reject { |t| t == ::Nil }.first %}
        Fm::Generable.type_to_schema({{ non_nil }})
      {% elsif T < Array %}
        items = Fm::Generable.type_to_schema({{ T.type_vars[0] }})
        JSON::Any.new({
          "type"  => JSON::Any.new("array"),
          "items" => items,
        } of String => JSON::Any)
      {% elsif T.class.has_method?(:json_schema) %}
        T.json_schema
      {% else %}
        JSON::Any.new({"type" => JSON::Any.new("string")} of String => JSON::Any)
      {% end %}
    end
  end
end
