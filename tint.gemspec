# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tint/version'

Gem::Specification.new do |spec|
  spec.name          = "tint"
  spec.version       = Tint::VERSION
  spec.authors       = ["Aleck Greenham"]
  spec.email         = ["greenhama13@gmail.com"]
  spec.summary       = "Declarative object decorators for JSON APIs"
  spec.description   = "Easily define object decorators for JSON APIs using simple declarative syntax"
  spec.homepage      = "https://github.com/greena13/tint"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "draper", "~> 2.1"
  spec.add_dependency "deep_merge", "~> 1.0"
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 0"
  spec.add_development_dependency "rspec", "~> 0"
end
