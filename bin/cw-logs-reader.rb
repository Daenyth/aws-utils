#! /usr/bin/env ruby

require 'aws-sdk'
require 'trollop'

require 'aws/utils/credentials'

class CWLogsReader
  attr_accessor :verbose

  def v(str)
    if (@verbose)
      $stderr.puts(str)
    end
  end

  def main()
    opts = Trollop::options do
      opt :aws_profile, "AWS profile in your AWS config file to use for credentials.",
              :default => "default"
      opt :aws_config_path, "Path to AWS config file.",
              :default => "~/.aws/config"
      opt :log_groups, "Regexp to match log groups against", 
              :short => 'g', :type => :string
      opt :log_streams, "Regexp to match log stream names against.      ",
              :short => 's', :default => ".*"
      opt :begin_at, "Time (relative or absolute) to begin logs at, or 'start'.",
              :short => 'b', :type => :string
      opt :end_at, "Time (relative or absolute) to end logs at, or 'now'.",
              :short => "e", :type => :string
      opt :tail, "Streams logs as they come in. Incompatible with --end-at.",
              :short => "t", :type => :boolean
      opt :verbose, "Provide verbose debug information to stderr.",
              :short => "v", :type => :boolean, :default => true
    end
    Trollop::die :log_groups, "must be specified" unless opts[:log_groups]
    Trollop::die :begin_at, "must be specified" unless opts[:begin_at]
    Trollop::die :end_at, "or --tail must be set" if !opts[:tail] && !opts[:end_at]
    Trollop::die :tail, "and --end-at are not compatible" if opts[:tail] && opts[:end_at]
  
    @verbose = opts[:verbose]

    opts[:log_groups] = regexp_compile(:log_groups, opts[:log_groups])
    opts[:log_streams] = regexp_compile(:log_streams, opts[:log_streams])

    ENV["AWS_PROFILE"] = opts[:aws_profile]
    ENV["AWS_CONFIG_PATH"] = opts[:aws_config_path]
    v("Options: #{opts.inspect}")
  
    creds = Aws::Utils::Credentials.acquire()
    v("Credentials: #{creds.inspect}")
  end

  def regexp_compile(opt_name, str)
    begin
      /#{str}/
    rescue => ex
      Trollop::die opt_name, "failed to compile to a regexp: '#{str}'"
    end
  end
end

CWLogsReader.new().main()