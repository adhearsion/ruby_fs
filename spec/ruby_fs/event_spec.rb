require 'spec_helper'

module RubyFS
  describe Event do
    subject { described_class.new nil, :event_name => 'FOO' }

    it { should be_a Response }

    its(:event_name) { should == 'FOO' }
  end
end
