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

      it "can send a command" do
        expect_connected_event
        expect_disconnected_event
        action = Action.new('Command', 'Command' => 'RECORD FILE evil', 'ActionID' => 666, 'Events' => 'On')
        mocked_server(1, lambda { @stream.send_action action }) do |val, server|
          val.should == action.to_s
        end
      end
    end

    it 'sends events to the client when the stream is ready' do
      mocked_server(1, lambda { @stream.send_data 'Foo' }) do |val, server|
        server.send_data <<-EVENT
Event: Hangup
Channel: SIP/101-3f3f
Uniqueid: 1094154427.10
Cause: 0

        EVENT
      end

      client_messages.should be == [
        Stream::Connected.new,
        Event.new('Hangup').tap do |e|
          e['Channel'] = 'SIP/101-3f3f'
          e['Uniqueid'] = '1094154427.10'
          e['Cause'] = '0'
        end,
        Stream::Disconnected.new
      ]
    end

    it 'sends responses to the client when the stream is ready' do
      mocked_server(1, lambda { @stream.send_data 'Foo' }) do |val, server|
        server.send_data <<-EVENT
Response: Success
ActionID: ee33eru2398fjj290
Message: Authentication accepted

        EVENT
      end

      client_messages.should be == [
        Stream::Connected.new,
        Response.new.tap do |r|
          r['ActionID'] = 'ee33eru2398fjj290'
          r['Message'] = 'Authentication accepted'
        end,
        Stream::Disconnected.new
      ]
    end

    it 'sends error to the client when the stream is ready and a bad command was send' do
      client.expects(:message_received).times(3).with do |r|
        case @sequence
        when 1
          r.should be_a Stream::Connected
        when 2
          r.should be_a Error
          r['ActionID'].should == 'ee33eru2398fjj290'
          r['Message'].should == 'You stupid git'
        when 3
          r.should be_a Stream::Disconnected
        end
        @sequence += 1
      end

      mocked_server(1, lambda { @stream.send_data 'Foo' }) do |val, server|
        server.send_data <<-EVENT
Response: Error
ActionID: ee33eru2398fjj290
Message: You stupid git

        EVENT
      end
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
