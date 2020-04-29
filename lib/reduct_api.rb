# frozen_string_literal: true

module ReductApi
  def reduct_endpoint
    Rails.configuration.reduct_endpoint
  end

  def video_endpoint
    Rails.configuration.twilio_video_endpoint
  end

  def twilio_rest_client
    config = Rails.configuration
    app = Rails.application

    begin
      res = Twilio::REST::Client.new(
        config.twilio_api_key,
        app.secrets[:twilio_api_secret]
      )

      logger.info(res)
      return res
    rescue Twilio::REST::TwilioError => e
      logger.warn(e.message)
    end
  end

  def get_twilio_token(name, room)
    config = Rails.configuration
    app = Rails.application

    token = Twilio::JWT::AccessToken.new(
      config.twilio_account_sid,
      config.twilio_api_key,
      app.secrets[:twilio_api_secret],
      [],
      identity: name
    )

    grant = Twilio::JWT::AccessToken::VideoGrant.new
    grant.room = room
    token.add_grant(grant)

    token.to_jwt
  end

  def twilio_room_path(name, room)
    config = Rails.configuration

    token = get_twilio_token(name, room.bbb_id)

    path = config.twilio_video_endpoint
    path + "/join/#{room.uid}/#{name}/#{token}"
  end
end
