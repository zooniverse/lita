# frozen_string_literal: true

require 'date'

module Lita
  module Handlers
    class TeamCalendarReminder < Handler
      route(/^(calendar event)\s*(.*)/, :cal_events, command: true,
                                                     help: { 'calendar event(s)' => 'displays events for the day' })

      def cal_events(response)
        # Get the environment configured authorization
        scope = 'https://www.googleapis.com/auth/calendar'
        authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: File.open('/app/creds.json'),
          scope: scope
        )

        authorizer.fetch_access_token!

        calendar = Google::Apis::CalendarV3::CalendarService.new
        calendar.authorization = authorizer

        page_token = nil
        now = Time.now.iso8601
        tomorrow = (Time.now + (60 * 60 * 24)).iso8601
        # begin
        result = calendar.list_events(ENV['TEST_CAL_ID'],
                                      time_min: now,
                                      time_max: tomorrow,
                                      page_token: page_token,
                                      show_deleted: false,
                                      fields: 'items(id,summary,start,html_link),next_page_token')
        cal_events = ''
        result.items.each do |e|
          # puts e.to_h
          cal_events = "#{cal_events}#{e&.summary} #{e&.start&.date_time&.to_s} #{e&.html_link}\n"
        end
        puts cal_events
        # rescue StandardError => e
        #   puts e
        # end

        response.reply(cal_events)
      end

      Lita.register_handler(self)
    end
  end
end
