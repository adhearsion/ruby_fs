require 'spec_helper'

module RubyFS
  describe Stream do
    let(:server_port) { 50000 - rand(1000) }

    before do
      def client.message_received(message)
        @messages ||= Queue.new
        @messages << message
      end

      def client.messages
        @messages
      end
    end

    let :client_messages do
      messages = []
      messages << client.messages.pop until client.messages.empty?
      messages
    end

    def mocked_server(times = nil, fake_client = nil, &block)
      mock_target = MockServer.new
      mock_target.expects(:receive_data).send(*(times ? [:times, times] : [:at_least, 1])).with &block
      s = ServerMock.new '127.0.0.1', server_port, mock_target
      @stream = Stream.new '127.0.0.1', server_port, lambda { |m| client.message_received m }
      fake_client.call if fake_client.respond_to? :call
      s.join
      @stream.join
    end

    def expect_connected_event
      client.expects(:message_received).with Stream::Connected.new
    end

    def expect_disconnected_event
      client.expects(:message_received).with Stream::Disconnected.new
    end

    before { @sequence = 1 }

    describe "after connection" do
      it "should be started" do
        expect_connected_event
        expect_disconnected_event
        mocked_server(0) do |val, server|
          @stream.started?.should be_true
        end
      end

      it "can send data" do
        expect_connected_event
        expect_disconnected_event
        mocked_server(1, lambda { @stream.send_data "foo" }) do |val, server|
          val.should == "foo"
        end
      end
    end

    it 'sends events to the client when the stream is ready' do
      mocked_server(1, lambda { @stream.send_data 'Foo' }) do |val, server|
        server.send_data 'foo'
      end

      client_messages.should be == [
        Stream::Connected.new,
        'foo',
        Stream::Disconnected.new
      ]
    end

    it 'puts itself in the stopped state and fires a disconnected event when unbound' do
      expect_connected_event
      expect_disconnected_event
      mocked_server(1, lambda { @stream.send_data 'Foo' }) do |val, server|
        @stream.stopped?.should be false
      end
      @stream.alive?.should be false
    end
  end
end
