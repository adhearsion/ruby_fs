MockServer = Class.new

class ServerMock
  include Celluloid::IO

  def initialize(host, port, mock_target = MockServer.new)
    @server = TCPServer.new host, port
    @mock_target = mock_target
    @clients = []
    run!
  end

  def finalize
    Logger.debug "ServerMock finalizing"
    @server.close if @server
    @clients.each(&:close)
  end

  def run
    after(1) { terminate }
    loop { handle_connection! @server.accept }
  end

  def handle_connection(socket)
    @clients << socket
    _, port, host = socket.peeraddr
    Logger.debug "MockServer Received connection from #{host}:#{port}"
    loop { receive_data socket.readpartial(4096) }
  end

  def receive_data(data)
    Logger.debug "ServerMock receiving data: #{data}"
    @mock_target.receive_data data, self
  end

  def send_data(data)
    @clients.each { |client| client.write data }
  end
end

def client
  @client ||= mock('Client')
end
