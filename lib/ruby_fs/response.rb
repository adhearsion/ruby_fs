module RubyFS
  class Response
    attr_reader :headers, :content

    def initialize(headers = nil, content = nil)
      @headers, @content = headers || {}, content || {}
    end

    def ==(other)
      other.is_a?(self.class) && [:headers, :content].all? do |att|
        other.send(att) == self.send(att)
      end
    end

    def respond_to?(name)
      super || content.has_key?(name)
    end

    def method_missing(name, *args, &block)
      return content[name] if content.has_key?(name)
      super
    end
  end
end
