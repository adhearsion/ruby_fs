require 'json'

require 'ruby_fs/lexer'

module RubyFS
  class Stream
    class ConnectionStatus
      def eql?(other)
        other.is_a? self.class
      end

      alias :== :eql?
    end

    Connected     = Class.new ConnectionStatus
    Disconnected  = Class.new ConnectionStatus

    include Celluloid::IO

    def initialize(host, port, secret, event_callback, events = true)
      super()
      @host, @port, @secret, @event_callback, @events = host, port, secret, event_callback, events
      @command_callbacks = []
      @lexer = Lexer.new method(:receive_request)
    end

    [:started, :stopped, :ready].each do |state|
      define_method("#{state}?") { @state == state }
    end

    def run
      logger.debug "Starting up..."
      @socket = TCPSocket.from_ruby_socket ::TCPSocket.new(@host, @port)
      post_init
      loop { receive_data @socket.readpartial(4096) }
    rescue EOFError, IOError
      logger.info "Client socket closed!"
      terminate
    end

    def send_data(data)
      logger.trace "[SEND] #{data.to_s}"
      @socket.write data.to_s
    end

    def command(command, options = {}, &block)
      @command_callbacks << (block || lambda { |reply| logger.debug "Reply to a command (#{command}) without a callback: #{reply.inspect}" })
      string = "#{command}\n"
      options.each_pair do |key, value|
        string << "#{key.to_s.gsub '_', '-'}: #{value}\n" if value
      end
      string << "\n"
      send_data string
    end

    def api(action, &block)
      command "api #{action}", &block
    end

    def bgapi(action, &block)
      command "bgapi #{action}", &block
    end

    def sendmsg(call, options = {}, &block)
      command "SendMsg #{call}", options, &block
    end

    def application(call, appname, options = nil, &block)
      sendmsg call, :call_command => 'execute', :execute_app_name => appname, :execute_app_arg => options, &block
    end

    def shutdown
      @socket.close if @socket
    end

    def finalize
      logger.debug "Finalizing stream"
      @state = :stopped
      fire_event Disconnected.new
    end

    def fire_event(event)
      @event_callback.call event
    end

    def logger
      super
    rescue
      @logger ||= begin
        logger = Logger
        logger.define_singleton_method :trace, logger.method(:debug)
        logger
      end
    end

    private

    def receive_data(data)
      logger.trace "[RECV] #{data}"
      @lexer << data
    end

    def receive_request(headers, content)
      case headers[:content_type]
      when 'text/event-json'
        fire_event Event.new(headers, json_content_2_hash(content))
      when 'command/reply'
        @command_callbacks.pop.call CommandReply.new(headers)
      when 'auth/request'
        command "auth #{@secret}" do
          command "event json ALL" if @events
        end
      else
        raise "Unknown request type received (#{headers.inspect})"
      end
    end

    def json_content_2_hash(content)
      json = JSON.parse content
      {}.tap do |hash|
        json.each_pair do |k, v|
          hash[k.downcase.gsub(/-/,"_").intern] = v
        end
      end
    end

    def post_init
      @state = :started
      fire_event Connected.new
    end
  end
end
