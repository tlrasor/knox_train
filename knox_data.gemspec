lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "knox_train/version"

Gem::Specification.new do |spec|
  spec.name          = "knox_train"
  spec.version       = KnoxTrain::VERSION
  spec.authors       = ["Travis Rasor"]
  spec.email         = ["travis@thathanka.org"]

  spec.summary       = "The noble train of data — restic backup orchestration"
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/tlrasor/knox_train"

  spec.required_ruby_version = ">= 4.0"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake",    "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"

  spec.add_runtime_dependency "chronic_duration",  "~> 0.10"
  spec.add_runtime_dependency "os",                "~> 1.1"
  spec.add_runtime_dependency "terminal-notifier", "~> 2.0"
  spec.add_runtime_dependency "tty-command",       "~> 0.10"
  spec.add_runtime_dependency "tty-logger",        "~> 0.6"
  spec.add_runtime_dependency "tty-progressbar",   "~> 0.18"
  spec.add_runtime_dependency "tty-which",         "~> 0.5"
  spec.add_runtime_dependency "thor",              "~> 1.3"
  spec.add_runtime_dependency "dry-schema",        "~> 1.13"
  spec.add_runtime_dependency "tty-table",         "~> 0.12"
end
