# encoding: utf-8

require 'spec_helper'
require 'timeout'

module RubyFS
  describe Stream do
    let(:server_port) { 50000 - rand(1000) }

    def client
      @client ||= mock('Client')
    end

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

    let(:secret)  { 'ClueCon' }
    let(:events)  { false }

    def mocked_server(times = nil, fake_client = nil, &block)
      mock_target = MockServer.new
      mock_target.should_receive(:receive_data).send(*(times ? [:exactly, times] : [:at_least, 1])).with &block
      s = ServerMock.new '127.0.0.1', server_port, mock_target
      @stream = Stream.new '127.0.0.1', server_port, secret, lambda { |m| client.message_received m }, events
      @stream.async.run
      sleep 0.1
      fake_client.call s if fake_client.respond_to? :call
      Celluloid::Actor.join s
      Timeout.timeout 5 do
        Celluloid::Actor.join @stream
      end
    end

    def expect_connected_event
      client.should_receive(:message_received).with Stream::Connected.new
    end

    def expect_disconnected_event
      client.should_receive(:message_received).with Stream::Disconnected.new
    end

    before { @sequence = 1 }

    describe "after connection" do
      it "should be started" do
        expect_connected_event
        expect_disconnected_event
        mocked_server(0) do |val, server|
          @stream.should be_started
        end
      end

      it "can send data" do
        expect_connected_event
        expect_disconnected_event
        mocked_server(1, lambda { |server| @stream.send_data "foo" }) do |val, server|
          val.should == "foo"
        end
      end

      it "can be shut down" do
        expect_connected_event
        expect_disconnected_event
        mocked_server(0, lambda { |server| @stream.shutdown }) do |val, server|
          @stream.should be_started
        end
        @stream.alive?.should be false
      end
    end

    it 'sends events to the client when the stream is ready' do
      mocked_server(1, lambda { |server| @stream.send_data 'Foo' }) do |val, server|
        server.send_data %Q(
Content-Length: 776
Content-Type: text/event-json

{
 "Event-Name": "HEARTBEAT",
 "Core-UUID": "2ad09a34-c056-11e1-b095-fffeda3ce54f",
 "FreeSWITCH-Hostname": "blmbp.home",
 "FreeSWITCH-Switchname": "blmbp.home",
 "FreeSWITCH-IPv4": "192.168.1.74",
 "FreeSWITCH-IPv6": "::1",
 "Event-Date-Local": "2012-06-27 19:43:32",
 "Event-Date-GMT": "Wed, 27 Jun 2012 18:43:32 GMT",
 "Event-Date-Timestamp": "1340822612392823",
 "Event-Calling-File": "switch_core.c",
 "Event-Calling-Function": "send_heartbeat",
 "Event-Calling-Line-Number": "68",
 "Event-Sequence": "3526",
 "Event-Info": "System Ready",
 "Up-Time": "0 years, 0 days, 5 hours, 56 minutes, 40 seconds, 807 milliseconds, 21 microseconds",
 "Session-Count": "0",
 "Max-Sessions": "1000",
 "Session-Per-Sec": "30",
 "Session-Since-Startup": "4",
 "Idle-CPU": "100.000000"
}Content-Length: 629
Content-Type: text/event-json

{
 "Event-Name": "RE_SCHEDULE",
 "Core-UUID": "2ad09a34-c056-11e1-b095-fffeda3ce54f",
 "FreeSWITCH-Hostname": "blmbp.home",
 "FreeSWITCH-Switchname": "blmbp.home",
 "FreeSWITCH-IPv4": "192.168.1.74",
 "FreeSWITCH-IPv6": "::1",
 "Event-Date-Local": "2012-06-27 19:43:32",
 "Event-Date-GMT": "Wed, 27 Jun 2012 18:43:32 GMT",
 "Event-Date-Timestamp": "1340822612392823",
 "Event-Calling-File": "switch_scheduler.c",
 "Event-Calling-Function": "switch_scheduler_execute",
 "Event-Calling-Line-Number": "65",
 "Event-Sequence": "3527",
 "Task-ID": "2",
 "Task-Desc": "heartbeat",
 "Task-Group": "core",
 "Task-Runtime": "1340822632"
})
      end

      client_messages.should be == [
        Stream::Connected.new,
        Event.new({:content_length => '776', :content_type => 'text/event-json'}, {:event_name => "HEARTBEAT", :core_uuid => "2ad09a34-c056-11e1-b095-fffeda3ce54f", :freeswitch_hostname => "blmbp.home", :freeswitch_switchname => "blmbp.home", :freeswitch_ipv4 => "192.168.1.74", :freeswitch_ipv6 => "::1", :event_date_local => "2012-06-27 19:43:32", :event_date_gmt => "Wed, 27 Jun 2012 18:43:32 GMT", :event_date_timestamp => "1340822612392823", :event_calling_file => "switch_core.c", :event_calling_function => "send_heartbeat", :event_calling_line_number => "68", :event_sequence => "3526", :event_info => "System Ready", :up_time => "0 years, 0 days, 5 hours, 56 minutes, 40 seconds, 807 milliseconds, 21 microseconds", :session_count => "0", :max_sessions => "1000", :session_per_sec => "30", :session_since_startup => "4", :idle_cpu => "100.000000"}),
        Event.new({:content_length => '629', :content_type => 'text/event-json'}, {:event_name => "RE_SCHEDULE", :core_uuid => "2ad09a34-c056-11e1-b095-fffeda3ce54f", :freeswitch_hostname => "blmbp.home", :freeswitch_switchname => "blmbp.home", :freeswitch_ipv4 => "192.168.1.74", :freeswitch_ipv6 => "::1", :event_date_local => "2012-06-27 19:43:32", :event_date_gmt => "Wed, 27 Jun 2012 18:43:32 GMT", :event_date_timestamp => "1340822612392823", :event_calling_file => "switch_scheduler.c", :event_calling_function => "switch_scheduler_execute", :event_calling_line_number => "65", :event_sequence => "3527", :task_id => "2", :task_desc => "heartbeat", :task_group => "core", :task_runtime => "1340822632"}),
        Stream::Disconnected.new
      ]
    end

    it "can send commands and returns the response" do
      expect_connected_event
      expect_disconnected_event
      reply = CommandReply.new(:content_type => 'command/reply', :reply_text => '+OK accepted')
      mocked_server(1, lambda { |server| @stream.command('foo').should == reply }) do |val, server|
        val.should == "foo\n\n"
        server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
      end
    end

    it "continues delivering events after executing a command" do
      expect_connected_event
      client.should_receive(:message_received).with RubyFS::Event.new({:content_length => "668", :content_type => "text/event-json"}, {:command => "sendevent message_waiting", :mwi_messages_waiting => "yes", :mwi_message_account => "sip:userc@192.168.79.100", :mwi_voice_message => "2/0 (0/0)", :event_uuid => "3b8fc6e0-8828-4622-8687-f31c8f60cbf1", :event_name => "MESSAGE_WAITING", :core_uuid => "4d678800-a20c-49fb-8c05-7e83ca6f791b", :freeswitch_hostname => "pbx", :freeswitch_switchname => "pbx", :freeswitch_ipv4 => "10.0.2.15", :freeswitch_ipv6 => "::1", :event_date_local => "2015-12-12 00:43:05", :event_date_gmt => "Sat, 12 Dec 2015 00:43:05 GMT", :event_date_timestamp => "1449880985640858", :event_calling_file => "mod_event_socket.c", :event_calling_function => "parse_command", :event_calling_line_number => "2239", :event_sequence => "465"})
      expect_disconnected_event
      reply = CommandReply.new(:content_type => 'command/reply', :reply_text => '+OK 3b8fc6e0-8828-4622-8687-f31c8f60cbf1')
      mocked_server(1, lambda { |server| @stream.command('sendevent message_waiting', 'MWI-Messages-Waiting' => 'yes', 'MWI-Message-Account' => 'sip:userc@192.168.79.100', 'MWI-Voice-Message' => '2/0 (0/0)').should == reply }) do |val, server|
        val.should == %Q(sendevent message_waiting
MWI-Messages-Waiting: yes
MWI-Message-Account: sip:userc@192.168.79.100
MWI-Voice-Message: 2/0 (0/0)

)

        server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK 3b8fc6e0-8828-4622-8687-f31c8f60cbf1

)
        server.send_data %Q(
Content-Length: 668
Content-Type: text/event-json

{"Command":"sendevent message_waiting","MWI-Messages-Waiting":"yes","MWI-Message-Account":"sip:userc@192.168.79.100","MWI-Voice-Message":"2/0 (0/0)","Event-UUID":"3b8fc6e0-8828-4622-8687-f31c8f60cbf1","Event-Name":"MESSAGE_WAITING","Core-UUID":"4d678800-a20c-49fb-8c05-7e83ca6f791b","FreeSWITCH-Hostname":"pbx","FreeSWITCH-Switchname":"pbx","FreeSWITCH-IPv4":"10.0.2.15","FreeSWITCH-IPv6":"::1","Event-Date-Local":"2015-12-12 00:43:05","Event-Date-GMT":"Sat, 12 Dec 2015 00:43:05 GMT","Event-Date-Timestamp":"1449880985640858","Event-Calling-File":"mod_event_socket.c","Event-Calling-Function":"parse_command","Event-Calling-Line-Number":"2239","Event-Sequence":"465"})
      end
    end

    it "can send commands with options" do
      expect_connected_event
      expect_disconnected_event
      mocked_server(1, lambda { |server| @stream.async.command 'foo', :one => 1, :foo_bar => :doo_dah }) do |val, server|
        val.should == %Q(foo
one: 1
foo-bar: doo_dah

)
      end
    end

    it "can send API commands and returns the response" do
      expect_connected_event
      expect_disconnected_event
      reply = CommandReply.new({:content_type => 'api/response', :content_length => '41'}, '+OK 396dd34a-10ba-11e2-b64a-37a9f8360f21')
      mocked_server(1, lambda { |server| @stream.api('foo').should == reply }) do |val, server|
        val.should == "api foo\n\n"
        server.send_data %Q(
Content-Type: api/response
Content-Length: 41

+OK 396dd34a-10ba-11e2-b64a-37a9f8360f21

)
      end
    end

    it "can send background API commands and returns the response" do
      expect_connected_event
      expect_disconnected_event
      reply = CommandReply.new(:content_type => 'command/reply', :reply_text => '+OK Job-UUID: 4e8344be-c1fe-11e1-a7bf-cf9911a69d1e', :job_uuid => '4e8344be-c1fe-11e1-a7bf-cf9911a69d1e')
      mocked_server(1, lambda { |server| @stream.bgapi('foo').should == reply }) do |val, server|
        val.should == "bgapi foo\n\n"
        server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK Job-UUID: 4e8344be-c1fe-11e1-a7bf-cf9911a69d1e
Job-UUID: 4e8344be-c1fe-11e1-a7bf-cf9911a69d1e

)
      end
    end

    it "can send messages to calls with options and returns the response" do
      expect_connected_event
      expect_disconnected_event
      reply = CommandReply.new(:content_type => 'command/reply', :reply_text => '+OK accepted')
      mocked_server(1, lambda { |server| @stream.sendmsg('aUUID', :call_command => 'execute').should == reply }) do |val, server|
        val.should == %Q(SendMsg aUUID
call-command: execute

)
        server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
      end
    end

    it "can execute applications on calls without options and returns the response" do
      expect_connected_event
      expect_disconnected_event
      reply = CommandReply.new(:content_type => 'command/reply', :reply_text => '+OK accepted')
      mocked_server(1, lambda { |server| @stream.application('aUUID', 'answer').should == reply }) do |val, server|
        val.should == %Q(SendMsg aUUID
call-command: execute
execute-app-name: answer

)
        server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
      end
    end

    it "can execute applications on calls with options (in the body) and returns the response" do
      expect_connected_event
      expect_disconnected_event
      reply = CommandReply.new(:content_type => 'command/reply', :reply_text => '+OK accepted')
      mocked_server(1, lambda { |server| @stream.application('aUUID', 'playback', '/tmp/test.wav').should == reply }) do |val, server|
        val.should == %Q(SendMsg aUUID
call-command: execute
execute-app-name: playback
content-type: text/plain
content-length: 13

/tmp/test.wav

)
        server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
      end
    end

    it 'authenticates when requested' do
      mocked_server(1, lambda { |server| server.send_data "Content-Type: auth/request\n\n" }) do |val, server|
        val.should == "auth ClueCon\n\n"
        server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
      end

      client_messages.should be == [
        Stream::Connected.new,
        Stream::Disconnected.new
      ]
    end

    context 'with events turned on' do
      let(:events) { true }

      it 'sets the event mask after authenticating' do
        mocked_server(2, lambda { |server| server.send_data "Content-Type: auth/request\n\n" }) do |val, server|
          case @sequence
          when 1
            val.should == "auth ClueCon\n\n"
            server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
          when 2
            val.should == "event json ALL\n\n"
            server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
          end
          @sequence += 1
        end

        client_messages.should be == [
          Stream::Connected.new,
          Stream::Disconnected.new
        ]
      end
    end

    context 'with events turned off' do
      it 'does not set the event mask after authenticating' do
        mocked_server(1, lambda { |server| server.send_data "Content-Type: auth/request\n\n" }) do |val, server|
          val.should == "auth ClueCon\n\n"
          server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
        end

        client_messages.should be == [
          Stream::Connected.new,
          Stream::Disconnected.new
        ]
      end
    end

    context 'with an event mask fully specified as a string' do
      let(:events) { 'CODEC CHANNEL_STATE' }

      it 'sets the event mask after authenticating' do
        mocked_server(2, lambda { |server| server.send_data "Content-Type: auth/request\n\n" }) do |val, server|
          case @sequence
          when 1
            val.should == "auth ClueCon\n\n"
            server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
          when 2
            val.should == "event json CODEC CHANNEL_STATE\n\n"
            server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
          end
          @sequence += 1
        end

        client_messages.should be == [
          Stream::Connected.new,
          Stream::Disconnected.new
        ]
      end
    end

    context 'with an event mask fully specified as an array' do
      let(:events) { ['CODEC', 'CHANNEL_STATE'] }

      it 'sets the event mask after authenticating' do
        mocked_server(2, lambda { |server| server.send_data "Content-Type: auth/request\n\n" }) do |val, server|
          case @sequence
          when 1
            val.should == "auth ClueCon\n\n"
            server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
          when 2
            val.should == "event json CODEC CHANNEL_STATE\n\n"
            server.send_data %Q(
Content-Type: command/reply
Reply-Text: +OK accepted

)
          end
          @sequence += 1
        end

        client_messages.should be == [
          Stream::Connected.new,
          Stream::Disconnected.new
        ]
      end
    end

    context 'when receiving a disconnect notice' do
      it 'puts itself in the stopped state and fires a disconnected event' do
        expect_connected_event
        expect_disconnected_event
        mocked_server(0, lambda { |server| server.send_data "Content-Type: text/disconnect-notice\n\n" }) do |val, server|
          @stream.stopped?.should be false
        end
        @stream.alive?.should be false
      end
    end

    it 'puts itself in the stopped state and fires a disconnected event when unbound' do
      expect_connected_event
      expect_disconnected_event
      mocked_server(1, lambda { |server| @stream.send_data 'Foo' }) do |val, server|
        @stream.stopped?.should be false
      end
      @stream.alive?.should be false
    end
  end
end
