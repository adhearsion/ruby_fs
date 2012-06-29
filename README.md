# RubyFS [![Build Status](https://secure.travis-ci.org/adhearsion/ruby_fs.png?branch=master)](http://travis-ci.org/adhearsion/ruby_fs)
RubyFS is a FreeSWITCH EventSocket client library in Ruby and based on Celluloid actors with the sole purpose of providing a connection to the EventSocket API. RubyFS does not provide any features beyond connection management and protocol parsing. Actions are sent over the wire, and responses come back via callbacks. It's up to you to match these up into something useful. In this regard, RubyFS is very similar to [Blather](https://github.com/sprsquish/blather) for XMPP or [Punchblock](https://github.com/adhearsion/punchblock), the Ruby 3PCC library. In fact, Punchblock uses RubyFS under the covers for its FreeSWITCH implementation.

## Installation
    gem install ruby_fs

## Usage
```ruby
require 'ruby_fs'

client = RubyFS::Stream.new '127.0.0.1', 8021, 'ClueCon', lambda { |e| p e }

client.start
```

## Links
* [Source](https://github.com/adhearsion/ruby_fs)
* [Documentation](http://rdoc.info/github/adhearsion/ruby_fs/master/frames)
* [Bug Tracker](https://github.com/adhearsion/ruby_fs/issues)

## Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  * If you want to have your own version, that is fine but bump version in a commit by itself so I can ignore when I pull
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2012 Ben Langfeld. MIT licence (see LICENSE for details).
