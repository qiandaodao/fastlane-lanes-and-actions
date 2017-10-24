module Fastlane
  module Actions

    class BuglyAction < Action
      def self.run(params)
        require 'json'
        require 'faraday'
        require 'faraday_middleware'

        UI.message('Starting uploading mapping file to Bugly...')

        connection = Faraday.new(:url => "https://api.bugly.qq.com", :request => { :timeout => 300 }) do |builder|
          builder.request :multipart
          builder.response :logger
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end

        response = connection.post do |req|
          req.url "/openapi/file/upload/symbol?app_key=#{params[:app_key]}&app_id=#{:app_id}"
          req.headers['Content-Type'] = 'multipart/form-data'
          req.body = {
            :api_version => '1',
            :app_id => "#{params[:app_id]}",
            :app_key => "#{params[:app_key]}",
            :symbolType => (params[:platform] == 'android' ? '1' : '2'),
            :bundleId => params[:package_id],
            :productVersion => "#{params[:version_name]}",
            :fileName => "symbol_#{params[:version_name]}.#{params[:platform] == 'android' ? 'txt' : 'zip'}",
            :file => Faraday::UploadIO.new(params[:mapping_file_path], 'text/plain')
          }
        end

        if parse_response(response)
          UI.success("Uploading mapping file to Bugly successfully!")
        else
          UI.user_error!("Error when trying to uploading mapping file to Bugly.")
        end

      rescue Faraday::Error::TimeoutError
        UI.user_error! "Timed out while uploading mapping file to Bugly." and abort
      end

      def self.parse_response(response)
        if response.body \
            && response.body['rtcode'] == 0 \
            && response.body['data']['reponseCode'] == '0'
          return true
        else
          UI.user_error!("Error uploading symbol file to Bugly: #{response.body}")
          return false
        end
      end
      private_class_method :parse_response

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Upload mapping file to Bugly"
      end

      def self.details
        "You can retrieve your App id and App key on [your settings page](https://www.bugly.qq.com/account/index/)"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :app_id,
                                       env_name: "FL_BUGLY_APP_ID",
                                       description: "App ID for Bugly",
                                       is_string: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("No App ID given, pass using `app_id: 'id'`") unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :app_key,
                                       env_name: "FL_BUGLY_APP_KEY",
                                       description: "App Key for Bugly",
                                       is_string: true,
                                       verify_block: proc do |value|
                                          UI.user_error!("No App Key given, pass using `app_key: 'key'`") unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :platform,
                                       env_name: "FL_BUGLY_PLATFORM",
                                       description: "platform for mapping file",
                                       verify_block: proc do |value|
                                         UI.user_error!("No platform given, pass using `platform: 'platform'`") unless (value and not value.empty?)
                                         UI.user_error!("Platform name doesn't exist, the available platform is `android` or `ios`") unless (value == 'android' or value == 'ios')
                                       end),
          FastlaneCore::ConfigItem.new(key: :package_id,
                                       env_name: "FL_BUGLY_PACKAGE_ID",
                                       description: "Package id for corresponding app",
                                       verify_block: proc do |value|
                                         UI.user_error!("No package id given, pass using `package_id: 'package_id'`") unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :mapping_file_path,
                                       env_name: "FL_BUGLY_MAPPING_FILE_PATH",
                                       description: "Mapping file path",
                                       verify_block: proc do |value|
                                         UI.user_error!("No mapping file path given, pass using `mapping_file_path: 'path'`") unless (value and not value.empty?)
                                         UI.user_error!("Couldn't find mapping file at path '#{value}'") unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :version_name,
                                       env_name: "FL_BUGLY_VERSION_NAME",
                                       description: "Version name for mapping file",
                                       verify_block: proc do |value|
                                         UI.user_error!("No version name given, pass using `version_name: 'version'`") unless (value and not value.empty?)
                                       end)
        ]
      end

      def self.output
        [
        ]
      end

      def self.authors
        ["flyeek"]
      end

      def self.is_supported?(platform)
        [:android, :ios].include?(platform)
      end

      def self.category
        :release
      end
    end
  end
end
