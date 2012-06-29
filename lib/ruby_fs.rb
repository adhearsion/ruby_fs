%w{
  uuidtools
  future-resource
  logger
  countdownlatch
  celluloid/io
}.each { |f| require f }

class Logger
  alias :trace :debug
end

module RubyFS
end

%w{
  command_reply
  event
  response
  stream
  version
}.each { |f| require "ruby_fs/#{f}" }
