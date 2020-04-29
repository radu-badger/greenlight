# frozen_string_literal: true

# BigBlueButton open source conferencing system - http://www.bigbluebutton.org/.
#
# Copyright (c) 2018 BigBlueButton Inc. and by respective authors (see below).
#
# This program is free software; you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free Software
# Foundation; either version 3.0 of the License, or (at your option) any later
# version.
#
# BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.

require 'twilio-ruby'

module ReductServer
  include ReductApi

  extend ActiveSupport::Concern

  # Checks if a room is running on the BigBlueButton server.
  def room_running?(uid)
    logger.info(twilio_client)
    logger.info("Looking for room: #{uid}")

    room = twilio_client.video.rooms(uid)

    begin
      room_rec = room.fetch

      logger.info("Room record: #{room_rec}")

      return room_rec.status == 'in-progress'
    rescue Twilio::REST::TwilioError => e
      logger.info(e.message)
      return false
    end
  end

  # Returns a list of all running meetings
  def all_running_meetings
    twilio_client.video.rooms.list(status: 'in-progress', limit: 50)
  end

  # Returns a URL to join a user into a meeting.
  def join_path(room, name, options = {}, _uid = nil)
    start_session(room, options)

    twilio_room_path(name, room)
  end

  # Creates a meeting on the BigBlueButton server.
  def start_session(room, options = {})
    unless room_running?(room.uid)
      twilio_create_options = {
        record_participants_on_connect: options[:meeting_recorded].to_s,
        type: 'group-small',
        unique_name: room.uid,
        status_callback: room_record_hook_url(@room),
        status_callback_method: 'POST'
      }

      logger.info("Created room with options: #{twilio_create_options}")

      # Send the create request.
      meeting = twilio_client.video.rooms.create(twilio_create_options)

      room.update_attributes(bbb_id: meeting.sid)

      # meeting = bbb_server.create_meeting(room.name, room.bbb_id, create_options)
      # Update session info.
      room.update_attributes(sessions: room.sessions + 1, last_session: DateTime.now)
    end

    if options[:meeting_recorded]
      reduct_create_options = {
        "meta_reduct-origin-version": Greenlight::Application::VERSION,
        "meta_reduct-origin": "Greenlight",
        "meta_reduct-origin-server-name": options[:host],
        logoutURL: options[:meeting_logout_url] || '',
      }

    end
  end

  def get_sessions(uid)
    twilio_client.video.rooms.list(unique_name: uid)
  end

  def get_recordings(uid)
    sessions = get_sessions(uid).map(&:sid)

    twilio_client.video.recordings.list(grouping_sid: sessions)
  end

  # Gets the number of recordings for this room
  def recording_count(uid)
    get_recordings(uid).length
    # bbb_server.get_recordings(meetingID: bbb_id)[:recordings].length
  end

  # Update a recording from a room
  def update_recording(record_id, meta)
    meta[:recordID] = record_id
    # bbb_server.send_api_request("updateRecordings", meta)
  end

  # Deletes a recording from a room.
  def delete_recording(record_id)
    # bbb_server.delete_recordings(record_id)
  end

  # Deletes all recordings associated with the room.
  def delete_all_recordings(bbb_id)
    # record_ids = bbb_server.get_recordings(meetingID: bbb_id)[:recordings].pluck(:recordID)
    # bbb_server.delete_recordings(record_ids) unless record_ids.empty?
  end
end
