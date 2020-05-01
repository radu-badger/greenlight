# frozen_string_literal: true

require 'net/http'
require 'json'

module ReductApi
  class LoginError < StandardError
  end

  def reduct_endpoint
    Rails.configuration.reduct_endpoint
  end

  def video_endpoint
    Rails.configuration.twilio_video_endpoint
  end

  def reduct_uri(cmd)
    URI.parse(reduct_endpoint).merge(cmd)
  end

  def reduct_post(cmd, content, _headers = {})
    api_token = Rails.application.secrets(:reduct_api_token)

    post = Net::HTTP::Post.new(reduct_uri(cmd))
    post['x-using-reduct-fetch'] = 'true'
    post['cookie'] = "token=#{api_token}"
    post.body = content.to_json

    post
  end

  def reduct_http
    # Create the HTTP objects
    uri = URI.parse(reduct_endpoint)

    reduct_http = Net::HTTP.new(uri.host, uri.port)

    yield reduct_http
  end

  def reduct_userlog(op, path, content)
    payload = { op: op, path: path, content: content }

    reduct_post('userlog', payload)
  end

  def reduct_put_doc(doc_id, title, project_id = Rails.configuration.reduct_default_project)
    doc = {
      title: title,
      doc_id: doc_id,
      project_id: project_id,
      transcription_confirmation_time: DateTime.now.iso8601,
      media: {}
    }

    reduct_http do |reduct_http|
      userlog_cmd = reduct_userlog('put', ['doc', doc_id], doc)

      logger.info("Sending request command: #{userlog_cmd}")
      reduct_http.request(userlog_cmd)
    end
  end

  def reduct_doc_uri_import(doc_id, *uris)
    data = {
      urls: uris,
      auto_start_times: 'true'
    }

    reduct_http do |reduct_http|
      upload_cmd = reduct_post("url-import?doc=#{doc_id}", data)

      logger.info("Sending upload command: #{userlog_cmd}")
      reduct_http.request(upload_cmd)
    end
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

  def get_twilio_media_redirect(uri)
    logger.info("Requesting TWILIO media redirect for URI #{uri}")

    response = twilio_client.request('video.twilio.com', 443, 'GET', uri)

    redirect_uri = NET::HTTP.get(URI(response.body['redirect_to']))

    logger.info("GOT:  #{redirect_uri}")
    redirect_uri
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
