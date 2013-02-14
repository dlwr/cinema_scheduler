# -*- coding: utf-8 -*-
require 'rubygems'
require 'mechanize'
require 'icalendar'
require 'kconv'
require 'google/api_client'
require 'yaml'
require_relative 'theater'

# theater = Hash.new
# theater["キネカ大森"] = {:path => "th197", :cal_id => "j8uo3jue9gpfnk4ac5l256ag7g@group.calendar.google.com"}
# theater["シネマヴェーラ渋谷"] = {:path => "th170", :cal_id => "7vaqlr1585bidb5nh4sbr98qro@group.calendar.google.com"}
# theater["ヒューマントラストシネマ渋谷"] = {:path => "th56", :cal_id => "ms97jlns9ckfonbqvmu9ivf2u8@group.calendar.google.com"}
# # theater["飯田橋ギンレイホール"] = "th321"
# # theater["ユナイテッド・シネマ豊洲"] = "th364"
# # theater["下高井戸シネマ"] = "th322"
# # theater["銀座シネパトス"] = "th122"
# # theater["銀座テアトルシネマ"] = "th507"
# # theater["三軒茶屋シネマ"] = "th71"
# # theater["三軒茶屋中央劇場"] = "th569"
# # theater["新橋文化劇場"] = "th512"
# # theater["新宿武蔵野館"] = "th2"
# # theater["新文芸坐"] = "th13"
# # theater["早稲田松竹"] = "th566"

if $theater[ARGV[0]]
  theater = Hash.new
  theater[ARGV[0]] = $theater[ARGV[0]]
else
  theater = $theater
end

movie_walker_plus_url = "http://movie.walkerplus.com"

agent = Mechanize.new

oauth_yaml = YAML.load_file('.google-api.yaml')
client = Google::APIClient.new
client.authorization.client_id = oauth_yaml["client_id"]
client.authorization.client_secret = oauth_yaml["client_secret"]
client.authorization.scope = oauth_yaml["scope"]
client.authorization.refresh_token = oauth_yaml["refresh_token"]
client.authorization.access_token = oauth_yaml["access_token"]

if client.authorization.refresh_token && client.authorization.expired?
  client.authorization.fetch_access_token!
end

service = client.discovered_api('calendar', 'v3')

theater.each {|theater_name, about|
  theater_dir = "data/" + theater_name + "/"
  url = about[:path]
  cal_id = about[:cal_id]
  puts theater_name
  FileUtils.mkdir_p(theater_dir) unless FileTest.exist?(theater_dir)
  open(theater_dir + "up_to_date", "w"){} unless FileTest.exist?(theater_dir + "up_to_date")

  yesterday = Hash.new
  open(theater_dir + "up_to_date", "r") {|f|
    while (title = f.gets) != nil
      yesterday[title.chomp] = Hash.new
      while (day = f.gets) != "\n"
        movie = yesterday[title.chomp]
        movie[day.chomp] = f.gets.chomp.split(",")
      end
    end
  }
  File.delete(theater_dir + "yesterday") if FileTest.exist?(theater_dir + "yesterday")
  File.rename(theater_dir + "up_to_date", "yesterday")

  cal = Icalendar::Calendar.new

  agent.get(movie_walker_plus_url + '/' + url + '/schedule.html')
  main_page = agent.page

  address = main_page.search('//*[@id="askTheaterPageLink"]/table/tr[1]/td/text()').inner_text

  all_movies = agent.page.search("div[@class='movie']")
  all_movies.each {|movie|
    option = movie.search("div[@class='movieTitle']/span").inject("") {|opt, s|
      annot = s.inner_text.gsub(/(\r\n|\r|\n|\s)/, "")
      if annot == "LAST" || annot == "NEW" || annot == nil || annot == "" || annot == "休映"
        opt
      else
        opt + " 《" + annot.strip + "》"
      end
    }
    title = movie.search("h2").inner_text + option
    # puts "	" + title

    begin
      info_link = movie.search('h2').search('a')[0]["href"]
      info_page = agent.get(movie_walker_plus_url + info_link)
    rescue
      # puts "		!!!can't find info page!!!"
      description = ""
      runtime = ""
    else
      description = info_page.search('//*[@id="mainInfo"]/p/text()').inner_text
      if (description == "")
        description = info_page.search('//*[@id="mainInfoNoImage"]/p/text()').inner_text
      end
      if (description == "")
        # puts "infomeation of " + title + "@" + theater_name + " missing"
      end
      
      runtime = info_page.search('//*[@id="infoBox"]/table/tr[4]/td/span').inner_text
      if runtime == ""
        runtime = info_page.search('//*[@id="infoBox"]/table/tr[5]/td/span').inner_text
      end
      if runtime == ""
        runtime = info_page.search('//*[@id="infoBox"]/table/tr[3]/td/span').inner_text
      end
      if runtime == ""
        runtime = info_page.search('//*[@id="infoBox"]/table/tr[4]/td').inner_text.gsub(/ \(.*\)/,'')
      end
      if runtime == ""
        runtime = info_page.search('//*[@id="infoBox"]/table/tr[2]/td/span').inner_text
      end
    end
    if runtime == "" || runtime.to_i == 0
      File.open("custom_runtime", "r") {|f|
        while (line = f.gets) != nil
          if line.chomp.index(title)
            runtime = f.gets.chomp
            break
          end
        end
      }
    end
    title_out = false
    if runtime == "" || runtime.to_i == 0
      puts "	" + title
      title_out = true
      puts "		!!! can't find runtime"
      next
    end
    schedule = Hash.new
    schedule_link = movie.search("a").last['href']
    schedule_page = agent.get(movie_walker_plus_url + schedule_link)
    schedule_page.search('//*[@id="pageHeaderWrap"]/div[2]/div[2]/table').each {|schedule_table|
      schedule_table.xpath('tr')[0].xpath('th').each {|th|
        schedule[th["class"]] = th.inner_text
      }
      schedule_table.xpath('tr')[2].xpath('td').each {|td|
        week_day = td["class"].split(" ")[0]
        showtimes = td.inner_text.gsub(/\(.*\)/,'').split(" ")
        unless showtimes.index("劇場問合") || showtimes.index("休館") || showtimes.index("休映") || showtimes == []
          schedule[schedule[week_day]] = showtimes
        end
        schedule.delete(week_day)
      }
    }
    open(theater_dir + 'up_to_date', "w") unless FileTest.exist?(theater_dir + "up_to_date")
    open(theater_dir + "up_to_date", "a") {|f|
      f.puts title
      schedule.each {|day, showtimes|
        next if showtimes.index("劇場問合") || showtimes.index("休館") || showtimes.index("休映") || showtimes == []
        f.puts day
        f.puts showtimes.join(",")
      }
      f.puts "\n"
    }
    add = Hash.new
    schedule_yesterday = yesterday[title]

    if description == ""
      puts "	" + title if title_out != true
      title_out = true
      puts "		!!! can't find description"
    end
    if runtime == ""
      puts "	" + title if title_out != true
      title_out = true
      puts "		!!! can't find runtime"
    end
    if schedule_yesterday == nil
      puts "	" + title if title_out != true
      title_out = true
      puts "		this is new title"
      add = schedule
      add.each {|day, time|
        puts "		" + day +"  " + time.join(",")
      }
    else
      schedule.each {|day, showtimes|
        if schedule_yesterday[day] == nil
          puts title if title_out != true
          title_out = true
          add[day] = schedule[day]
          puts "		new schedule:" + day + ":" + add[day].join(",")
        elsif (diff = schedule[day] - schedule_yesterday[day]) != []
          add[day] = diff
          puts title if title_out != true
          title_out = true
          puts "		new schedule:" + day + ":" + add[day].join(",")
        end
      }
    end
    if add.size != nil
      add.each {|day, showtimes|
        day = day.split("/")
        showtimes.each {|time|
          next if time.index("劇場問合") != nil || time.index("休館") || time.index("休映") || time == ""
          time = time.split(":")
          midnight = false
          if time[0].to_i >= 24
            time[0] = (time[0].to_i - 24).to_s
            midnight = true
          end
          begin
            start_time = DateTime.new(2013, day[0].to_i, day[1].to_i, time[0].to_i, time[1].to_i, 0, "+0900")
            start_time = start_time + 1 if midnight
            end_time = start_time + Rational(1, 24 * 60) * runtime.to_i
          rescue
            puts "crash at " + title + "@" + theater_name + "scheduling"
            next
          end
          event = {
            'summary' => title,
            'location' => address,
            'start' => {
              'dateTime' => start_time
            },
            'end' => {
              'dateTime' => end_time
            },
            'description' => description
          }
          if client.authorization.refresh_token && client.authorization.expired?
            client.authorization.fetch_access_token!
          end
          result = client.execute(:api_method => service.events.insert,
                                  :parameters => {'calendarId' => cal_id},
                                  :body => JSON.dump(event),
                                  :headers => {'Content-Type' => 'application/json'})
          # cal.event do
          #   begin
          #     start_time = DateTime.new(2013, day[0].to_i, day[1].to_i, time[0].to_i, time[1].to_i)
          #     start_time = start_time + 1 if midnight
          #   rescue
          #     puts "crash at " + title + "@" + theater_name + "scheduling"
          #     next
          #   end
          #   end_time = start_time + Rational(1, 24 * 60) * runtime.to_i
          #   dtstart start_time, {'TZID' => 'Asia/Tokyo'}
          #   dtend end_time, {'TZID' => 'Asia/Tokyo'}
          #   summary title
          #   description description
          #   location address
          # end
        }
      }
    end
  }
  # File.open(theater_name + "/schedule.ics", "w+b") { |f|
  #   f.write(cal.to_ical)
  # }
  puts "\n"
}
