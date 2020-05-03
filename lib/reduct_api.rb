# frozen_string_literal: true

require 'net/http'
require 'json'

module ReductApi
  class LoginError < StandardError
  end

  def reduct_uri(cmd = '')
    URI.parse(Rails.configuration.reduct_endpoint).merge(cmd)
  end

  def video_endpoint
    Rails.configuration.twilio_video_endpoint
  end

  def reduct_get(cmd)
    api_token = Rails.application.secrets[:reduct_api_token]

    req = Net::HTTP::Get.new(reduct_uri(cmd))
    req['x-using-reduct-fetch'] = 'true'
    req['cookie'] = "token=#{api_token}"

    req.body = content.to_json

    logger.info("Reduct GET: #{req.uri}, #{req.body}")

    reduct_http do |http|
      http.get(req)
    end
  end

  def reduct_userdb
    JSON.parse(reduct_get('userdb'))
  end

  def reduct_post(cmd, content)
    api_token = Rails.application.secrets[:reduct_api_token]

    post = Net::HTTP::Post.new(reduct_uri(cmd))
    post['x-using-reduct-fetch'] = 'true'
    post['cookie'] = "token=#{api_token}"

    post.body = content.to_json

    logger.info("Reduct POST: #{post.uri}, #{post.body}")

    post
  end

  def reduct_http
    # Create the HTTP objects
    reduct_http = Net::HTTP.new(reduct_uri.host, reduct_uri.port)
    reduct_http.use_ssl = (reduct_uri.scheme == "https")

    reduct_http.start

    yield reduct_http
  end

  def reduct_userlog(op, path, content)
    payload = { op: op, path: path, data: content }

    reduct_post('userlog', payload)
  end

  def reduct_put_doc(doc_id, title, project_id)
    doc = {
      title: title,
      doc_id: doc_id,
      project_id: project_id,
      transcription_confirmation_time: DateTime.now.iso8601,
      media: {}
    }

    userlog_cmd = reduct_userlog('put', ['doc', doc_id], doc)

    logger.info("Sending request command: #{userlog_cmd.uri}: #{userlog_cmd.body}")

    reduct_http do |http|
      res = http.request(userlog_cmd)

      logger.info("REDUCT response #{res.code}, #{res.message}")
    end
  end

  def reduct_put_project(project_id, title, editors, org_editable = false)
    project = {
      title: title,
      organization: Rails.configuration.reduct_org_id,
      editors: editors,
      org_editable: org_editable
    }

    userlog_cmd = reduct_userlog('put', ['project', project_id], project)

    logger.info("Sending request command: #{userlog_cmd.uri}: #{userlog_cmd.body}")

    reduct_http do |http|
      res = http.request(userlog_cmd)

      logger.info("REDUCT response #{res.code}, #{res.message}")
    end
  end

  def reduct_doc_uri_import(doc_id, *uris)
    data = {
      urls: uris,
      auto_start_times: 'true'
    }

    reduct_http do |http|
      upload_cmd = reduct_post("url-import?doc=#{doc_id}", data)

      logger.info("Sending upload command: #{upload_cmd}")
      res = http.request(upload_cmd)

      logger.info("REDUCT response #{res.code}, #{res.message}")
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

      logger.info("TWILIO response #{res}")
      return res
    rescue Twilio::REST::TwilioError => e
      logger.warn(e.message)
    end
  end

  def get_twilio_media_redirect(uri)
    logger.info("Requesting TWILIO media redirect for URI #{uri}")

    response = twilio_client.request('video.twilio.com', 443, 'GET', uri)

    redirect_uri = response.body['redirect_to']

    logger.info("GOT:  #{redirect_uri}")
    redirect_uri
  end

  def get_twilio_token(name, room_name)
    config = Rails.configuration
    app = Rails.application

    token = Twilio::JWT::AccessToken.new(
      config.twilio_account_sid,
      config.twilio_api_key,
      app.secrets[:twilio_api_secret],
      [],
      identity: name
    )

    room = twilio_client.video.rooms(room_name).fetch
    room_sid = room.sid

    grant = Twilio::JWT::AccessToken::VideoGrant.new
    grant.room = room_sid
    token.add_grant(grant)

    token.to_jwt
  end

  def twilio_room_path(name, room)
    config = Rails.configuration

    token = get_twilio_token(name, room.uid)

    path = config.twilio_video_endpoint
    path + "/join/#{room.name}/#{name}/#{token}"
  end
end
