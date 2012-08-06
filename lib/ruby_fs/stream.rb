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

    #
    # Connect to the server and begin handling data
    def run
      logger.debug "Starting up..."
      @socket = TCPSocket.from_ruby_socket ::TCPSocket.new(@host, @port)
      post_init
      loop { receive_data @socket.readpartial(4096) }
    rescue EOFError, IOError, Errno::ECONNREFUSED
      logger.info "Client socket closed!"
      terminate
    end

    #
    # Send raw string data to the FS server
    #
    # @param [#to_s] data the data to send over the socket
    def send_data(data)
      logger.trace "[SEND] #{data.to_s}"
      @socket.write data.to_s
    end

    #
    # Send a FreeSWITCH command with options and a callback for the response
    #
    # @param [#to_s] command the command to run
    # @param [optional, Hash] options the command's options, where keys have _ substituted for -
    #
    # @return [RubyFS::Response] response the command's response object
    def command(command, options = {}, &callback)
      uuid = SecureRandom.uuid
      @command_callbacks << (callback || lambda { |reply| signal uuid, reply })
      string = "#{command}\n"
      options.each_pair do |key, value|
        string << "#{key.to_s.gsub '_', '-'}: #{value}\n" if value
      end
      string << "\n"
      send_data string
      wait uuid unless callback
    end

    #
    # Send an API action
    #
    # @param [#to_s] action the API action to execute
    #
    # @return [RubyFS::Response] response the command's response object
    def api(action)
      command "api #{action}"
    end

    #
    # Send an API action in the background
    #
    # @param [#to_s] action the API action to execute
    #
    # @return [RubyFS::Response] response the command's response object
    def bgapi(action)
      command "bgapi #{action}"
    end

    #
    # Send a message to a particular call
    #
    # @param [#to_s] call the call ID to send the message to
    # @param [optional, Hash] options the message options
    #
    # @return [RubyFS::Response] response the message's response object
    def sendmsg(call, options = {})
      command "SendMsg #{call}", options
    end

    #
    # Execute an application on a particular call
    #
    # @param [#to_s] call the call ID on which to execute the application
    # @param [#to_s] appname the app to execute
    # @param [optional, String] options the application options
    #
    # @return [RubyFS::Response] response the application's response object
    def application(call, appname, options = nil)
      sendmsg call, :call_command => 'execute', :execute_app_name => appname, :execute_app_arg => options
    end

    #
    # Shutdown the stream and disconnect from the socket
    def shutdown
      @socket.close if @socket
    end

    # @private
    def finalize
      logger.debug "Finalizing stream"
      @state = :stopped
      fire_event Disconnected.new
    end

    #
    # Fire an event to the specified callback
    #
    # @param [Object] event the event to fire
    def fire_event(event)
      @event_callback.call event
    end

    #
    # The stream's logger object
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
          command! "event json ALL" if @events
        end
      when 'text/disconnect-notice'
        terminate
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
