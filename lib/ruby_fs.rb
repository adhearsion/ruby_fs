%w{
  uuidtools
  future-resource
  logger
  girl_friday
  countdownlatch
  celluloid/io
}.each { |f| require f }

class Logger
  alias :trace :debug
end

module RubyFS
end

%w{
  action
  client
  error
  event
  lexer
  metaprogramming
  response
  stream
  version
}.each { |f| require "ruby_fs/#{f}" }
