# encoding: utf-8

require 'spec_helper'

module RubyFS
  describe Response do

    its(:headers) { should == {} }
    its(:content) { should == {} }

    context "when created with headers" do
      let(:headers) { {:foo => 'bar'} }

      subject { Event.new headers }

      its(:headers) { should == headers }
      its(:content) { should == {} }
    end

    context "when created with content" do
      let(:content) { {:foo => 'bar'} }

      subject { Event.new nil, content }

      its(:headers) { should == {} }
      its(:content) { should == content }

      it "makes content values available via #[]" do
        subject.should_not have_key(:bar)
        subject[:bar].should == nil

        subject.should have_key(:foo)
        subject[:foo].should == 'bar'
      end
    end

    context "when created with headers and content" do
      let(:headers) { {:foo => 'bar'} }
      let(:content) { {:doo => 'dah'} }

      subject { Event.new headers, content }

      its(:headers) { should == headers }
      its(:content) { should == content }
    end

    describe "equality" do
      context "with another kind of object" do
        it "should not be equal" do
          Event.new.should_not == :foo
        end
      end

      context "with the same headers and the same content" do
        let :event1 do
          Event.new({:foo => 'bar'}, :doo => 'bah')
        end

        let :event2 do
          Event.new({:foo => 'bar'}, :doo => 'bah')
        end

        it "should be equal" do
          event1.should == event2
        end
      end

      context "with the same headers and different content" do
        let :event1 do
          Event.new({:foo => 'bar'}, :doo => 'bah')
        end

        let :event2 do
          Event.new({:foo => 'bar'}, :doo => 'dah')
        end

        it "should not be equal" do
          event1.should_not == event2
        end
      end

      context "with the different headers and the same content" do
        let :event1 do
          Event.new({:foo => 'bar'}, :doo => 'bah')
        end

        let :event2 do
          Event.new({:foo => 'baz'}, :doo => 'bah')
        end

        it "should not be equal" do
          event1.should_not == event2
        end
      end

      context "with different headers and different content" do
        let :event1 do
          Event.new({:foo => 'bar'}, :foo => 'baz')
        end

        let :event2 do
          Event.new({:foo => 'baz'}, :foo => 'bar')
        end

        it "should not be equal" do
          event1.should_not == event2
        end
      end
    end
  end
end
