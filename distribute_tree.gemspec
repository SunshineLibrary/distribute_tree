Gem::Specification.new do |s|
  s.name        = 'distribute_tree'
  s.version     = '0.0.1'
  s.date        = '2013-12-04'
  s.summary     = File.read("README.markdown").split(/===+/)[1].strip.split("\n")[0]
  s.description = s.summary
  s.authors     = ["David Chen"]
  s.email       = 'mvjome@gmail.com'
  s.homepage    = 'https://github.com/SunshineLibrary/distribute_tree'
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test/{functional,unit}/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency "rails", ">= 3.2"
  s.add_dependency 'haml-rails'
  s.add_dependency "resque"
  s.add_dependency "mongoid"

  s.add_development_dependency 'pry-debugger'
  s.add_development_dependency 'guard-test'
  s.add_development_dependency 'mongoid-rspec'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'factory_girl_rails'
  s.add_development_dependency 'database_cleaner'

  s.files = `git ls-files`.split("\n")
end
