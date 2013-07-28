# vim: sw=2 et

Gem::Specification.new do |s|
  s.name        = 'stcoveralls'
  s.license     = 'MPL-2.0'
  s.version     = '0.1.0'
  s.authors     = ['Scott Talbot']
  s.email       = 's@chikachow.org'
  s.summary     = 'Coveralls.io submission client'
  s.files       = %w| LICENSE README.md lib/stcoveralls.rb |
  s.homepage    = 'https://github.com/cysp/stcoveralls-ruby'
  s.add_runtime_dependency('rest-client')
end
