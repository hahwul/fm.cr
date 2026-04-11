module Fm
  # Response returned by the model.
  struct Response
    # The text content of the response.
    getter content : String

    def initialize(@content : String)
    end

    # Returns `true` if the response content is empty.
    def empty? : Bool
      @content.empty?
    end

    def to_s(io : IO) : Nil
      io << @content
    end

    def to_s : String
      @content
    end
  end
end
