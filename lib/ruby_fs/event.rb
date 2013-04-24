# encoding: utf-8

require 'ruby_fs/response'

module RubyFS
  class Event < Response
    #
    # @return [String] The name of the event
    def event_name
      content[:event_name]
    end
  end
end
