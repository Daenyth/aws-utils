# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aws/utils/version'

Gem::Specification.new do |s|
  s.name        = 'aws-utils'
  s.version     = Aws::Utils::VERSION
  s.licenses    = ['Apache-2.0']
  s.summary     = "A set of helpful-ish scripts to make working with AWS a little easier."
  s.description = ""
  s.authors     = ["Ed Ropple"]
  s.email       = 'eropple+aws-utils@localytics.com'
  s.homepage    = 'https://github.com/localytics/aws-utils'
  
  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.6"
  s.add_development_dependency "rake"
  
  s.add_runtime_dependency 'aws-sdk-core', '2.0.0.rc12'
  s.add_runtime_dependency 'trollop', '~> 2.0'
  
  
  s.post_install_message = <<-ENDMESSAGE
Many of the tools within #{s.name} support using an AWS config file
from aws-cli (~/.aws/config) to get user credentials. If you'd like to
save some typing down the line, install `pip` and run the following:

    pip install aws-cli
    aws cli configure

Thanks for installing #{s.name}! If you run into any problems or have a
generally useful script to add to the collection, please get in touch!

 - Github: https://github.com/localytics/#{s.name}
 - Email: eropple+aws-utils@localytics.com
 
  ENDMESSAGE
end