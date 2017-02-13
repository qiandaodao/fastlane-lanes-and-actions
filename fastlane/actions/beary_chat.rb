module Fastlane
  module Actions
    module SharedValues
    end

    class BearyChatAction < Action
      def self.run(params)
        require 'json'
        require 'faraday'
        require 'faraday_middleware'

        UI.message('Starting sending message to BearyChat...')

        connection = Faraday.new(:url => "#{params[:robot_url]}", :request => { :timeout => 120 }) do |builder|
          builder.request :json
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end

        requestBody = Hash[
          "text" => "#{params[:message_title]}",
          "attachments" => [
           {
             "text" => "#{params[:message_text]}",
             "color" => "#00cc99",
           }
          ]
        ]

        if params[:message_image]
          requestBody["attachments"][0]["images"] = [{"url" => "#{params[:message_image]}"}]
        end

        if params[:message_color]
          requestBody['attachments'][0]['color'] = params[:message_color];
        end

        response = connection.post do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = requestBody.to_json
        end

        if parse_response(response)
          UI.success("Sending message to BearyChat successfully!")
        else
          UI.user_error!("Error when trying to send message to BearyChat.")
        end

      rescue Faraday::Error::TimeoutError
        say_error "Timed out while sending message to BearyChat." and abort
      end

      def self.parse_response(response)
        if response.body && response.body.key?('code') && response.body['code'] == 0

          return true
        else
          UI.user_error!("Error sending message to BearyChat: #{response.body}")

          return false
        end
      end
      private_class_method :parse_response

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Send a message to Beary"
      end

      def self.details
        "You can see detail info on [BearyChat official page](https://www.bearychat.com/)"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :robot_url,
                                       env_name: "FL_BEARY_CHAT_ROBOT_KEY",
                                       description: "Webhook url for BearyChat Incoming Robot",
                                       verify_block: proc do |value|
                                          UI.user_error!("No Webhook url for BearyChat given, pass using `robot_url: 'url'`") unless (value and not value.empty?)
                                       end),
         FastlaneCore::ConfigItem.new(key: :message_title,
                                      env_name: "FL_BEARY_CHAT_MESSAGE_TITLE",
                                      description: "Title for message",
                                      verify_block: proc do |value|
                                         UI.user_error!("No Message Title for BearyChatAction given, pass using `message_title: 'title'`") unless (value and not value.empty?)
                                      end),
          FastlaneCore::ConfigItem.new(key: :message_text,
                                       env_name: "FL_BEARY_CHAT_MESSAGE_TEXT",
                                       description: "Text for message",
                                       verify_block: proc do |value|
                                          UI.user_error!("No Message Text for BearyChatAction given, pass using `message_title: 'title'`") unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :message_image,
                                       env_name: "FL_BEARY_CHAT_IMAGE_URL",
                                       description: "Image for message. Optioinal",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :message_color,
                                       env_name: "FL_BEARY_CHAT_message_color",
                                       description: "Color for message. Optioinal",
                                       optional: true)
        ]
      end

      def self.output
      end

      def self.return_value
        # If you method provides a return value, you can describe here what it does
      end

      def self.authors
        ["flyeek"]
      end

      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end
    end
  end
end
