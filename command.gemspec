require_relative "lib/command/version"

Gem::Specification.new do |spec|
  spec.name = "command"
  spec.version = Command::VERSION
  spec.authors = ["Bo Jeanes", "Andy O'Neil"]
  spec.email = ["me@bjeanes.com", "andy@andyofniall.net"]

  spec.summary = "Simple command object library with wrapped result objects"
  spec.homepage = "https://github.com/bjeanes/command"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bjeanes/command"
  spec.metadata["changelog_uri"] = "https://github.com/bjeanes/command/releases"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files =
    Dir.chdir(File.expand_path('..', __FILE__)) do
      `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
    end
  spec.require_paths = ["lib"]
end
