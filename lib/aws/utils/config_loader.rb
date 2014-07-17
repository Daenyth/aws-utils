module Aws
  module Utils
    module ConfigLoader
      public
      def self.load()
        filename = (ENV["AWS_CONFIG_PATH"] || "~/.aws/config").sub("~", Dir.home)
        if !File.exists?(filename)
          return nil
        end

        ret = {}
        current = "default"
        File.readlines(filename).each do |line|
          line = line.strip

          if line == "[default]"
            current = "default"
          elsif line.start_with?("[profile")
            current = /^\[profile ([A-Za-z\-\_\.0-9]+)\]$/.match(line)[1]
          else
            ret[current] ||= {}
            tokens = /([A-Za-z0-9\-\_\.]+)\s*\=\s*(\S+)/.match(line)
            if tokens
              ret[current][tokens[1]] = tokens[2]
            end
          end
        end
        ret
      end
    end
  end
end
