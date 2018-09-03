lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_interactor/version'

Gem::Specification.new do |spec|
  spec.name          = 'active_interactor'
  spec.version       = ActiveInteractor::VERSION
  spec.authors       = ['Yuku TAKAHASHI']
  spec.email         = ['yuku@qiita.com']

  spec.summary       = 'Simple use case interactor for Rails apps based on ActiveModel'
  spec.homepage      = 'https://github.com/yuku/active_interactor'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'activemodel', '~> 5.0'
  spec.add_dependency 'activesupport', '~> 5.0'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'codeclimate-test-reporter', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.58'
  spec.add_development_dependency 'rubocop-rspec', '~> 1.29'
  spec.add_development_dependency 'simplecov', '~> 0.16.1'
end
