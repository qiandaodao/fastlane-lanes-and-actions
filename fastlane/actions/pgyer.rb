module Fastlane
  module Actions
    module SharedValues
      PGYER_INSTALL_QRCODE_URL = :PGYER_INSTALL_QRCODE_URL
      PGYER_INSTALL_APP_KEY = :PGYER_INSTALL_APP_KEY
    end

    class PgyerAction < Action
      def self.run(params)
        require 'json'
        require 'faraday'
        require 'faraday_middleware'

        UI.message('Starting uploading ipa to Pgyer...')

        connection = Faraday.new(:url => "http://www.pgyer.com", :request => { :timeout => 120 }) do |builder|
          builder.request :multipart
          builder.request :json
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end

        requestBody = Hash[params.values.map do |key, value|
          case key
          when :user_key
            ['uKey', value]
          when :api_key
            ['_api_key', value]
          when :app_path
            ['file', Faraday::UploadIO.new(params[:app_path], 'application/octet-stream')]
          when :install_password
            ['password', value]
          else
            UI.user_error!("Unknown parameter: #{key}")
          end
        end]

        response = connection.post("/apiv1/app/upload", requestBody)

        if parse_response(response)
          UI.success("Upload to Pgyer successfully!")
          # UI.success("http://www.pgyer.com/apiv1/app/install?_api_key=#{params[:api_key]}&aKey=#{Actions.lane_context[SharedValues::PGYER_INSTALL_APP_KEY]}")
          return Actions.lane_context[SharedValues::PGYER_INSTALL_QRCODE_URL]
        else
          UI.user_error!("Error when trying to upload ipa to Pgyer.")
        end
      end

      def self.parse_response(response)
        if response.body && response.body.key?('code') && response.body['code'] == 0
          install_qrcode_url = response.body['data']['appQRCodeURL']
          install_app_key = response.body['data']['appKey']

          Actions.lane_context[SharedValues::PGYER_INSTALL_QRCODE_URL] = install_qrcode_url
          Actions.lane_context[SharedValues::PGYER_INSTALL_APP_KEY] = install_app_key

          return true
        else
          UI.error("Error uploading to Pgyer: #{response.body}")

          return false
        end
      end
      private_class_method :parse_response

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Upload a new adhoc build to Pgyer"
      end

      def self.details
        "You can retrieve your User key and API key on [your settings page](https://www.pgyer.com/account/index/)"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :user_key,
                                       env_name: "FL_PGYER_USER_KEY",
                                       description: "User Key for Pgyer",
                                       is_string: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("No User Key for PgyerAction given, pass using `user_key: 'key'`") unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :api_key,
                                       env_name: "FL_PGYER_API_KEY",
                                       description: "API Key for Pgyer",
                                       is_string: true,
                                       verify_block: proc do |value|
                                          UI.user_error!("No API Key for PgyerAction given, pass using `api_key: 'key'`") unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :app_path,
                                       env_name: "FL_PGYER_APP_PATH",
                                       description: "Path to your APP file",
                                       verify_block: proc do |value|
                                           UI.user_error!("Couldn't find app file at path '#{value}'") unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :install_password,
                                       env_name: "FL_PGYER_INSTALL_PASSWORD",
                                       description: "password when installing app. Default value is none",
                                       default_value: "")
        ]
      end

      def self.output
        [
          ['PGYER_INSTALL_QRCODE_URL', 'QRCode URL of the newly uploaded build'],
          ['PGYER_INSTALL_APP_KEY', 'App Key of the newly uploaded build']
        ]
      end

      def self.authors
        ["flyeek"]
      end

      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end

      def self.category
        :beta
      end
    end
  end
end
