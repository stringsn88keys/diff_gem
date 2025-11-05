Gem::Specification.new do |spec|
  spec.name          = "diff_gem"
  spec.version       = "0.1.1"
  spec.authors       = ["Thomas Powell"]
  spec.email         = ["twilliampowell@gmail.com"]

  spec.summary       = "Compare source code between two versions of a Ruby gem"
  spec.description   = "A tool to download and compare the source trees of two different versions of a Ruby gem, displaying differences in diff format"
  spec.homepage      = "https://github.com/stringsn88keys/diff_gem"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z 2>/dev/null`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "thor", "~> 1.0"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "pry", "~> 0.14"
end
