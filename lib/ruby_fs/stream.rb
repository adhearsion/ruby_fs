module RubyFS
  class Stream
    class ConnectionStatus
      def eql?(other)
        other.is_a? self.class
      end

      alias :== :eql?
    end

    Connected = Class.new ConnectionStatus
    Disconnected = Class.new ConnectionStatus

    include Celluloid::IO

    def initialize(host, port, event_callback)
      super()
      @event_callback = event_callback
      logger.debug "Starting up..."
      @socket = TCPSocket.from_ruby_socket ::TCPSocket.new(host, port)
      post_init
      run!
    end

    [:started, :stopped, :ready].each do |state|
      define_method("#{state}?") { @state == state }
    end

    def run
      loop { receive_data @socket.readpartial(4096) }
    rescue EOFError
      logger.info "Client socket closed!"
      current_actor.terminate!
    end

    def post_init
      @state = :started
      fire_event Connected.new
    end

    def send_data(data)
      logger.debug "[SEND] #{data.to_s}"
      @socket.write data.to_s
    end

    def receive_data(data)
      logger.debug "[RECV] #{data}"
      fire_event data
    end

    def finalize
      logger.debug "Finalizing stream"
      @socket.close if @socket
      @state = :stopped
      fire_event Disconnected.new
    end

    def fire_event(event)
      @event_callback.call event
    end

    def logger
      Logger
    end
  end
end
