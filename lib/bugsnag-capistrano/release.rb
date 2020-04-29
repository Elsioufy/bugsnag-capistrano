require "json"
require "net/http"
require "logger"

module Bugsnag
  module Capistrano
    class Release

      HEADERS = {"Content-Type" => "application/json"}
      DEFAULT_BUILD_ENDPOINT = "https://build.bugsnag.com/"
      DEFAULT_BUILD_TOOL_NAME = "bugsnag-capistrano"

      def self.notify(opts = {})
        opts[:endpoint] ||= DEFAULT_BUILD_ENDPOINT
        opts[:builder_name] ||= `whoami`
        opts[:build_tool] ||= DEFAULT_BUILD_TOOL_NAME

        parameters = {
          "apiKey" => opts[:api_key],
          "appVersion" => opts[:app_version],
          "autoAssignRelease" => opts[:auto_assign_release],
          "builderName" => opts[:builder_name],
          "buildTool" => opts[:build_tool],
          "metadata" => opts[:metadata],
          "releaseStage" => opts[:release_stage],
          "sourceControl" => {
            "provider" => opts[:source_control_provider],
            "revision" => opts[:revision],
            "repository" => opts[:repository]
          }
        }

        if parameters["apiKey"].nil?
          logger.warn("Cannot deliver notification. Missing required apiKey")
        elsif parameters["appVersion"].nil?
          logger.warn("Cannot deliver notification. Missing required appVersion")
        else
          payload_string = ::JSON.dump(parameters)
          self.deliver(opts[:endpoint], payload_string)
        end
      end

      def self.deliver(url, body)
        begin
          request(url, body)
        rescue StandardError => e
          logger.warn("Notification to #{url} failed, #{e.inspect}")
          logger.warn(e.backtrace)
        end
      end

      def self.request(url, body)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 15
        http.open_timeout = 15

        http.use_ssl = uri.scheme == "https"

        uri.path == "" ? "/" : uri.path
        request = Net::HTTP::Post.new(uri, HEADERS)
        request.body = body
        http.request(request)
      end

      def self.logger
        if @logger.nil?
          @logger = Logger.new(STDOUT)
          @logger.level = Logger::INFO
        end
        @logger
      end
    end
  end
end
