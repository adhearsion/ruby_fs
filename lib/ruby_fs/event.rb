require 'ruby_fs/response'

module RubyFS
  class Event < Response
    def event_name
      content[:event_name]
    end
  end
end
