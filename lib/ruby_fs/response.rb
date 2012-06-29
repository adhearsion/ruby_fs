module RubyFS
  class Response
    attr_reader :headers, :content

    extend Forwardable
    def_delegator :content, :[]
    def_delegator :content, :has_key?

    def initialize(headers = nil, content = nil)
      @headers, @content = headers || {}, content || {}
    end

    def ==(other)
      other.is_a?(self.class) && [:headers, :content].all? do |att|
        other.send(att) == self.send(att)
      end
    end
  end
end
