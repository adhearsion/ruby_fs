# encoding: utf-8

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

    finalizer :finalize

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
    rescue EOFError, IOError, Errno::ECONNREFUSED => e
      logger.info "Client socket closed due to (#{e.class}) #{e.message}!"
      async.terminate
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
      body_value = options.delete :command_body_value
      options.each_pair do |key, value|
        string << "#{key.to_s.gsub '_', '-'}: #{value}\n" if value
      end
      string << "\n" << body_value << "\n" if body_value
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
      opts = {call_command: 'execute', execute_app_name: appname}
      if options
        opts[:content_type]       = 'text/plain'
        opts[:content_length]     = options.bytesize
        opts[:command_body_value] = options
      end
      sendmsg call, opts
    end

    #
    # Shutdown the stream and disconnect from the socket
    alias :shutdown :terminate

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

    def finalize
      logger.debug "Finalizing stream"
      @socket.close if @socket
      @state = :stopped
      fire_event Disconnected.new
    end

    def receive_data(data)
      logger.trace "[RECV] #{data}"
      @lexer << data
    end

    def receive_request(headers, content)
      content.strip!
      case headers[:content_type]
      when 'text/event-json'
        fire_event Event.new(headers, json_content_2_hash(content))
      when 'command/reply', 'api/response'
        @command_callbacks.pop.call CommandReply.new(headers, (content == '' ? nil : content))
      when 'auth/request'
        command "auth #{@secret}" do
          async.command "event json #{event_mask}" if @events
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
          hash[k.downcase.gsub('-',"_").intern] = v
        end
      end
    end

    def post_init
      @state = :started
      fire_event Connected.new
    end

    def event_mask
      return 'ALL' if @events == true

      Array(@events).join(' ')
    end
  end
end
