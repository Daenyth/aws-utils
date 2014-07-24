#! /usr/bin/env ruby

require 'aws-sdk-core'
require 'trollop'

require 'aws/utils/credentials'

# parse time
def parse_time(str)
  if str
    case str.downcase.strip
      when 'now'
        Time.now
      when 'start'
        nil
      when /^[\+\-][0-9]+$/
        Time.at(Time.now.to_i + str.to_i)
      else
        Time.parse(str)
    end
  end
end

# millisecond to time
def ms_to_time(ms)
  Time.at(ms / 1000.0)
end

# time to milliseconds
def time_to_ms(time)
  time.is_a?(Time) ? time.to_i * 1000 : nil
end

class EventCollection
  include Enumerable
  attr_reader :stream, :start_time, :end_time

  def initialize(client, stream, options)
    @client = client
    @stream = stream
    @options = options
    @start_time = parse_time(options[:start_time])
    @end_time = parse_time(options[:end_time])
    @end_time_ms = @end_time ? time_to_ms(@end_time) : nil
    # puts "start time #{@start_time.inspect}, end time #{@end_time.inspect}, now #{Time.now}"
  end

  def each
    group_name = self.stream.group.attributes.log_group_name
    stream_name = self.stream.attributes.log_stream_name
    # puts "looking for #{group_name}, #{stream_name}"
    params = {
      :log_group_name => group_name,
      :log_stream_name => stream_name,
      :start_from_head => true
    }
    params[:start_time] = time_to_ms(@start_time) if @start_time
    params[:end_time]   = @end_time_ms + 10000 if @end_time_ms
    # puts("params for event each #{params.inspect}")
    pageable_response = @client.get_log_events(params)
    pageable_response.each do |page|
      page.events.each do |event|
        return if @end_time && event.timestamp >= @end_time_ms
        # puts("end time #{@end_time}")
        yield(event)
      end
    end
  end
end

class LogStream
  attr_reader :attributes, :group

  def initialize(client, group, attributes)
    @client = client
    @group = group
    @attributes = attributes
  end

  def events(options = {})
    EventCollection.new(@client, self, options)
  end
end

class LogStreamCollection
  include Enumerable

  attr_reader :group

  def initialize(client, group)
    @client = client
    @group = group
  end

  def each
    pageable_response = @client.describe_log_streams(:log_group_name => @group.attributes.log_group_name)
    pageable_response.each do |page|
      page.log_streams.each do |stream|
        yield(LogStream.new(@client, self.group, stream))
      end
    end
  end
end

class LogGroup
  attr_reader :attributes

  def initialize(client, attributes)
    @client = client
    @attributes = attributes
  end

  def streams
    LogStreamCollection.new(@client, self)
  end
end

class LogGroupCollection
  include Enumerable

  def initialize(client)
    @client = client
  end

  def each
    pageable_response = @client.describe_log_groups()
    pageable_response.each do |page|
      page.log_groups.each do |group|
        yield(LogGroup.new(@client, group))
      end
    end
  end
end

class CWLogsReader
  attr_accessor :verbose

  def v(str)
    if (@verbose)
      $stderr.puts(str)
    end
  end

  def find_streams(client, group_regex, stream_regex, begin_at)
    begin_at_time = parse_time(begin_at)
    # puts begin_at_time
    groups = LogGroupCollection.new(client).
      select{|g| g.attributes.log_group_name.match(group_regex)}

    groups.map do |group|
      streams = group.streams.select do |s|
        s.attributes.log_stream_name.match(stream_regex) &&
          (!begin_at_time || s.attributes.last_ingestion_time > (time_to_ms(begin_at_time)))
      end
      streams.map do |stream|
        stream
      end
    end.flatten
  end

  def main()
    opts = Trollop::options do
      opt :aws_profile, "AWS profile in your AWS config file to use for credentials.",
          :default => "default"

      opt :aws_config_path, "Path to AWS config file.",
          :default => "~/.aws/config"

      opt :region, "AWS region",
          :short => 'r',
          :default => 'us-east-1'

      opt :log_groups, "Regexp to match log groups against", 
          :short => 'g',
          :type => :string

      opt :log_streams, "Regexp to match log stream names against.",
          :short => 's',
          :default => ".*"

      opt :begin_at, "Time (relative or absolute) to begin logs at, or 'start'.",
          :short => 'b',
          :type => :string

      opt :end_at, "Time (relative or absolute) to end logs at, or 'now'.",
          :short => "e",
          :type => :string

      opt :tail, "Streams logs as they come in. Incompatible with --end-at.",
          :short => "t",
          :type => :boolean

      opt :verbose, "Provide verbose debug information to stderr.",
          :short => "v",
          :type => :boolean,
          :default => false
    end
    Trollop::die :log_groups, "must be specified" unless opts[:log_groups]
    Trollop::die :begin_at, "must be specified" unless opts[:begin_at]
    # Trollop::die :end_at, "or --tail must be set" if !opts[:tail] && !opts[:end_at]
    # Trollop::die :tail, "and --end-at are not compatible" if opts[:tail] && opts[:end_at]
  
    @verbose = opts[:verbose]

    opts[:log_groups] = regexp_compile(:log_groups, opts[:log_groups])
    opts[:log_streams] = regexp_compile(:log_streams, opts[:log_streams])

    ENV["AWS_PROFILE"] = opts[:aws_profile]
    ENV["AWS_CONFIG_PATH"] = opts[:aws_config_path]
    v("Options: #{opts.inspect}")
  
    creds = Aws::Utils::Credentials.acquire()
    creds = Aws::Credentials.new(creds[:access_key_id], creds[:secret_access_key])
    v("Credentials: #{creds.inspect}")

    client = Aws::CloudWatchLogs::Client.new(
      :region => opts[:region],
      :credentials => creds,
      :api_version => '2014-03-28'
    )

    streams = find_streams(client, opts[:log_groups], opts[:log_streams], opts[:begin_at])
    event_enumerators = streams.map do |s|
      s.events(:start_time => opts[:begin_at], :end_time => opts[:end_at]).each_entry
    end

    has_next = true

    while (has_next)
      peek_events = event_enumerators.
        each_with_index.
        map{|enum, i| [enum.peek,i] rescue nil}.
        reject{|event_i| event_i.nil?}
      min_event_i = peek_events.min_by{|event_i| event_i[0].timestamp}
      # print('.')
      $stdout.flush
      if min_event_i
        event = event_enumerators[min_event_i[1]].next
        ing_ts = ms_to_time(event.ingestion_time).utc.strftime('%Y-%m-%d %H:%M:%S UTC')
        ts = ms_to_time(event.timestamp).utc.strftime('%Y-%m-%d %H:%M:%S UTC')
        puts("ingestion_time: #{ing_ts}, timestamp: #{ts}, msg: #{event.message}")
      else
        has_next = false
      end
    end
  rescue Interrupt
    puts "Caught interrupt signal, exiting"
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