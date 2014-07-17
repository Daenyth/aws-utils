require "net/http"
require "uri"

require "aws/utils/config_loader"

module Aws
  module Utils
    module Credentials
      def self.acquire()
        if (ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"])
          { 
            :access_key_id => ENV["AWS_ACCESS_KEY_ID"],
            :secret_access_key => ENV["AWS_SECRET_ACCESS_KEY"]
          }
        else
          config_profile = ENV["AWS_PROFILE"] || "default"
          config = Aws::Utils::ConfigLoader.load()
          if config && config[config_profile]
            {
              :access_key_id => config[config_profile]["aws_access_key_id"],
              :secret_access_key => config[config_profile]["aws_secret_access_key"]
            }
          else
            begin
              iam_uri = URI.parse("http://169.254.169.254/latest/meta-data/iam/")
              response = Net::HTTP.start(iam_uri.host, iam_uri.port) do |http|
                http.read_timeout=1
                http.open_timeout=1
                http.get(iam_uri.path)
              end
              if response.code != 404
                "IAM"
              else
                nil
              end
            rescue
              nil
            end
          end
        end
      end
    end
  end
end