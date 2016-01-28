Gem::Specification.new do |spec|
  spec.name          = "lita-zooniverse"
  spec.version       = "0.1.0"
  spec.authors       = ["Zooniverse"]
  spec.email         = ["no-reply@zooniverse.org"]
  spec.description   = "Add a description"
  spec.summary       = "Add a summary"
  spec.homepage      = "https://github.com/zooniverse/lita"
  spec.license       = "BUGROFF"
  spec.metadata      = { "lita_plugin_type" => "handler" }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "lita", ">= 4.6"
  spec.add_runtime_dependency "httparty"
  spec.add_runtime_dependency "octokit"
  spec.add_runtime_dependency "jenkins_api_client"
  spec.add_runtime_dependency "aws-sdk", ">= 2"
  spec.add_runtime_dependency "a_vs_an"
  spec.add_runtime_dependency "panoptes-client"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rspec", ">= 3.0.0"
end
