Gem::Specification.new do |s|  
  s.name                  = 'logfile_transfer'
  s.version               = '0.1.3'
  s.date                  = '2013-10-18'
  s.summary               = 'Logfile Transfer'
  s.description           = 'Ruby monitoring and transform logfiles daemon.'
  s.author                = 'Cong Yan'
  s.email                 = 'xiaoyaoyouzizai@gmail.com'
  s.homepage              = 'https://github.com/xiaoyaoyouzizai/logfile_transfer'
  s.license               = 'Apache License, Version 2.0'
  s.required_ruby_version = '>= 1.8.7'
  s.files                 = [
    'lib/logfile_transfer.rb',
    'example.rb',
    'config.yaml',
    'README.md'
  ]
  s.add_dependency('file-monitor', '>= 0.1.3')
end