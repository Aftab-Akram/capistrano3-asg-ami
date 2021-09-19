# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capistrano/autoscaling/version'

Gem::Specification.new do |spec|
  spec.name          = 'capistrano3-asg-ami'
  spec.version       = Capistrano::AutoScaling::VERSION
  spec.authors       = ['Aftab Akram']
  spec.email         = ['aftabakram04@gmail.com']
  spec.summary       = %q{Capistrano 3 plugin for updating AWS Launch Template AMI}
  spec.description   = %q{Capistrano 3 plugin for updating AWS Launch Template AMI with autoscale group first healthy instance.}
  spec.homepage      = 'https://github.com/Aftab-Akram/capistrano3-asg-ami'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.2.10'
  spec.add_development_dependency 'rake'

  spec.add_dependency 'aws-sdk-ec2', '~> 1'
  spec.add_dependency 'aws-sdk-autoscaling', '~> 1'
  spec.add_dependency 'capistrano', '> 3.0.0'
  spec.add_dependency 'activesupport', '>= 4.0.0'
  spec.add_dependency 'capistrano-bundler', '~> 2'
end
