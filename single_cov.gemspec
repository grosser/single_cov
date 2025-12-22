# frozen_string_literal: true
name = "single_cov"
require "./lib/#{name.gsub("-", "/")}/version"

Gem::Specification.new name, SingleCov::VERSION do |s|
  s.summary = "Actionable code coverage."
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "https://github.com/grosser/#{name}"
  s.files = `git ls-files lib/ bin/ MIT-LICENSE`.split("\n")
  s.license = "MIT"
  s.required_ruby_version = '>= 3.2.0' # keep in sync with .rubocop.yml, .github/workflows/actions.yml

  s.add_development_dependency "bump"
  s.add_development_dependency "minitest"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rubocop"
  s.add_development_dependency "simplecov"
end
