# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ruby_fs/version"

Gem::Specification.new do |s|
  s.name        = "ruby_fs"
  s.version     = RubyFS::VERSION
  s.authors     = ["Ben Langfeld"]
  s.email       = ["ben@langfeld.me"]
  s.homepage    = "https://github.com/adhearsion/ruby_fs"
  s.summary     = %q{Wrapping FreeSWITCH EventSocket for rubyists}
  s.description = %q{A Ruby client library for the FreeSWITCH EventSocket API built on Celluloid.}

  s.rubyforge_project = "ruby_fs"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency %q<celluloid-io>, ["~> 0.13"]

  s.add_development_dependency %q<bundler>, ["~> 1.0"]
  s.add_development_dependency %q<rspec>, ["~> 2.5"]
  s.add_development_dependency %q<yard>, ["~> 0.6"]
  s.add_development_dependency %q<rake>, [">= 0"]
  s.add_development_dependency %q<guard-rspec>
  s.add_development_dependency %q<rb-fsevent>, ['~> 0.9']
end
