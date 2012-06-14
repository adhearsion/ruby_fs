require 'ruby_fs/response'

module RubyFS
  class Event < Response
    attr_reader :name

    def initialize(name)
      super()
      @name = name
    end

    def inspect_attributes
      [:name] + super
    end
  end
end # RubyFS
