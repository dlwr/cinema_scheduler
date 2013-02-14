require 'rubygems'
require 'google/api_client'
require 'yaml'
require_relative 'theater'

oauth_yaml = YAML.load_file('.google-api.yaml')
client = Google::APIClient.new
client.authorization.client_id = oauth_yaml["client_id"]
client.authorization.client_secret = oauth_yaml["client_secret"]
client.authorization.scope = oauth_yaml["scope"]
client.authorization.refresh_token = oauth_yaml["refresh_token"]
client.authorization.access_token = oauth_yaml["access_token"]
#client.authorization.application_name = "cinema_schedular"

if client.authorization.refresh_token && client.authorization.expired?
  client.authorization.fetch_access_token!
end

service = client.discovered_api('calendar', 'v3')

if $theater[ARGV[0]]
  id = $theater[ARGV[0]][:cal_id]
  result = client.execute(:api_method => service.events.list,
                          :parameters => {'calendarId' => id})
  while true
    events = result.data.items
    events.each do |e|
      puts e.summary
      begin
        puts "	" + e.start.dateTime.to_s
      rescue
       
      end
      client.execute(:api_method => service.events.delete,
                     :parameters =>
                     {
                       'calendarId' => id,
                       'eventId' => e.id,
                     }
                     )
    end
    if !(page_token = result.data.next_page_token)
      break
    end
    result = client.execute(:api_method => service.events.list,
                            :parameters =>
                            {
                              'calendarId' => 'primary',
                              'pageToken' => page_token,
                            }
                            )
  end
end
