module Fm
  # Response returned by the model.
  struct Response
    # The text content of the response.
    getter content : String

    def initialize(@content : String)
    end

    def to_s(io : IO) : Nil
      io << @content
    end

    def to_s : String
      @content
    end
  end
end
