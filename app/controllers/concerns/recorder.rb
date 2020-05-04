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

module Recorder
  extend ActiveSupport::Concern
  include RecordingsHelper

  # Fetches all recordings for a room.
  def recordings(uid, search_params = {}, ret_search_params = false)
    recs = get_recordings(uid)
    logger.info("Recorder recs: #{recs}")

    format_recordings(recs, search_params, ret_search_params)
  end

  # Fetches a rooms public recordings.
  def public_recordings(uid, search_params = {}, ret_search_params = false)
    search, order_col, order_dir, recs = recordings(uid, search_params, ret_search_params)
    [search, order_col, order_dir, { recordings: [] }]
  end

  # Makes paginated API calls to get recordings
  def all_recordings(room_uids, search_params = {}, ret_search_params = false, search_name = false)
    res = { recordings:
      room_uids.flat_map do |room_uid|
        get_recordings(room_uid)
      end }

    format_recordings(res, search_params, ret_search_params, search_name)
  end

  # Format, filter, and sort recordings to match their current use in the app
  def format_recordings(api_res, search_params, ret_search_params, _search_name = false)
    search = search_params[:search] || ""
    order_col = search_params[:column] && search_params[:direction] != "none" ? search_params[:column] : "end_time"
    order_dir = search_params[:column] && search_params[:direction] != "none" ? search_params[:direction] : "desc"

    search = search.downcase

    recs = api_res
    # recs = filter_recordings(api_res, search, search_name)
    # recs = sort_recordings(recs, order_col, order_dir)

    if ret_search_params
      [search, order_col, order_dir, recs]
    else
      recs
    end
  end

  def filter_recordings(api_res, search, search_name = false)
    api_res[:recordings].select do |r|
             (!r[:metadata].nil? && ((!r[:metadata][:name].nil? &&
                    r[:metadata][:name].downcase.include?(search)) ||
                  (r[:metadata][:"gl-listed"] == "true" && search == "public") ||
                  (r[:metadata][:"gl-listed"] == "false" && search == "unlisted"))) ||
               ((r[:metadata].nil? || r[:metadata][:name].nil?) &&
                 r[:name].downcase.include?(search)) ||
               r[:participants].include?(search) ||
               !r[:playbacks].select { |p| p[:type].downcase.include?(search) }.empty? ||
               (search_name && Room.find_by(bbb_id: r[:meetingID]).owner.email.downcase.include?(search))
    end
  end

  def sort_recordings(recs, order_col, order_dir)
    recs = case order_col
           when "end_time"
              recs.sort_by { |r| r[:endTime] }
           when "name"
              recs.sort_by do |r|
                if !r[:metadata].nil? && !r[:metadata][:name].nil?
                  r[:metadata][:name].downcase
                else
                  r[:name].downcase
                end
              end
           when "length"
              recs.sort_by { |r| r[:playbacks].reject { |p| p[:type] == "statistics" }.first[:length] }
           when "users"
              recs.sort_by { |r| r[:participants] }
           when "visibility"
              recs.sort_by { |r| r[:metadata][:"gl-listed"] }
           when "formats"
              recs.sort_by { |r| r[:playbacks].first[:type].downcase }
            else
              recs.sort_by { |r| r[:endTime] }
            end

    if order_dir == 'asc'
      recs
    else
      recs.reverse
    end
  end
end
