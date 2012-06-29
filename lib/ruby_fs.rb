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
  event
  stream
  version
}.each { |f| require "ruby_fs/#{f}" }
