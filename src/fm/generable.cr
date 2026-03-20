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
  #
  # You can use `Fm::Guide` annotations to add constraints:
  #
  # ```
  # struct Movie
  #   include JSON::Serializable
  #   include Fm::Generable
  #
  #   getter title : String
  #
  #   @[Fm::Guide(any_of: ["G", "PG", "PG-13", "R"])]
  #   getter rating : String
  #
  #   @[Fm::Guide(minimum: 1, maximum: 10)]
  #   getter score : Int32
  #
  #   @[Fm::Guide(pattern: "^[A-Z]")]
  #   getter director : String
  #
  #   @[Fm::Guide(min_items: 1, max_items: 5)]
  #   getter genres : Array(String)
  # end
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
            prop_schema = Fm::Generable.type_to_schema(\{{ivar.type}})

            \{% guide = ivar.annotation(Fm::Guide) %}
            \{% if guide %}
              _h = prop_schema.as_h

              \{% if guide[:description] %}
                _h["description"] = JSON::Any.new(\{{guide[:description]}})
              \{% end %}

              \{% if guide[:any_of] %}
                _h["enum"] = JSON::Any.new(\{{guide[:any_of]}}.map { |v| JSON::Any.new(v) })
              \{% end %}

              \{% if guide[:constant] %}
                _h["const"] = JSON::Any.new(\{{guide[:constant]}})
              \{% end %}

              \{% if guide[:minimum] %}
                _h["minimum"] = JSON::Any.new(\{{guide[:minimum]}}.to_i64)
              \{% end %}

              \{% if guide[:maximum] %}
                _h["maximum"] = JSON::Any.new(\{{guide[:maximum]}}.to_i64)
              \{% end %}

              \{% if guide[:pattern] %}
                _h["pattern"] = JSON::Any.new(\{{guide[:pattern]}})
              \{% end %}

              \{% if guide[:min_items] %}
                _h["minItems"] = JSON::Any.new(\{{guide[:min_items]}}.to_i64)
              \{% end %}

              \{% if guide[:max_items] %}
                _h["maxItems"] = JSON::Any.new(\{{guide[:max_items]}}.to_i64)
              \{% end %}

              \{% if guide[:count] %}
                _h["minItems"] = JSON::Any.new(\{{guide[:count]}}.to_i64)
                _h["maxItems"] = JSON::Any.new(\{{guide[:count]}}.to_i64)
              \{% end %}
            \{% end %}

            properties.as_h[\{{key}}] = prop_schema
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
      {% elsif T.union? %}
        # Non-nil union types → JSON Schema "oneOf"
        {% variants = T.union_types %}
        one_of = [] of JSON::Any
        {% for vt in variants %}
          one_of << Fm::Generable.type_to_schema({{ vt }})
        {% end %}
        JSON::Any.new({"oneOf" => JSON::Any.new(one_of)} of String => JSON::Any)
      {% elsif T < Enum %}
        # Enum types → JSON Schema "enum" with member names (snake_case)
        {% members = T.constants %}
        enum_values = [] of JSON::Any
        {% for m in members %}
          enum_values << JSON::Any.new({{ m.underscore.stringify }})
        {% end %}
        JSON::Any.new({
          "type" => JSON::Any.new("string"),
          "enum" => JSON::Any.new(enum_values),
        } of String => JSON::Any)
      {% elsif T < Array %}
        items = Fm::Generable.type_to_schema({{ T.type_vars[0] }})
        JSON::Any.new({
          "type"  => JSON::Any.new("array"),
          "items" => items,
        } of String => JSON::Any)
      {% elsif T < Hash %}
        # Hash(String, V) → JSON Schema object with additionalProperties
        additional = Fm::Generable.type_to_schema({{ T.type_vars[1] }})
        JSON::Any.new({
          "type"                 => JSON::Any.new("object"),
          "additionalProperties" => additional,
        } of String => JSON::Any)
      {% elsif T.class.has_method?(:json_schema) %}
        T.json_schema
      {% else %}
        JSON::Any.new({"type" => JSON::Any.new("string")} of String => JSON::Any)
      {% end %}
    end
  end
end
