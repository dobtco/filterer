$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "filterer/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "filterer"
  s.version     = Filterer::VERSION
  s.authors     = ["Adam Becker"]
  s.email       = ["adam@dobt.co"]
  s.homepage    = "https://github.com/dobtco/filterer"
  s.summary     = "Easily filter results from your ActiveRecord models."
  s.description = %{Filterer lets your users easily filter results from your ActiveRecord models.}
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 4.0.0"

  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'benchmark-ips'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'guard-rspec'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'sqlite3'
end
