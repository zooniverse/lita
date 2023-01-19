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
                                        fields: 'items(id,summary,start),next_page_token')
          result.items.each do |e|
            puts e.summary + ' ' + e.start.date_time.to_s + "\n"
          end
          puts result
        # rescue StandardError => e
        #   puts e
        # end

        response.reply("hello")
      end

      Lita.register_handler(self)
    end
  end
end
