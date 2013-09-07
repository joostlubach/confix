# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'confix/version'

Gem::Specification.new do |spec|
  spec.name          = "confix"
  spec.version       = Confix::VERSION
  spec.authors       = ["Joost Lubach"]
  spec.email         = ["joost@yoazt.com"]
  spec.description   = %q[ Easy-to-use configuration using a well-defined structure. ]
  spec.summary       = %q[ Easy-to-use configuration using a well-defined structure. ]
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.14"
end
