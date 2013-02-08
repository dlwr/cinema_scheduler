# -*- coding: utf-8 -*-
require 'rubygems'
require 'mechanize'
require 'icalendar'
require 'kconv'

theater = Hash.new
theater["キネカ大森"] = "th197"
theater["ヒューマントラストシネマ渋谷"] = "th56"
theater["銀座シネパトス"] = "th122"
theater["新宿武蔵野館"] = "th2"
theater["ユナイテッド・シネマ豊洲"] = "th364"
movie_walker_plus_url = "http://movie.walkerplus.com"

agent = Mechanize.new

theater.each {|theater_name, url|
  cal = Icalendar::Calendar.new
  # getメソッドでアクセス
  agent.get(movie_walker_plus_url + '/' + url + '/schedule.html')
  main_page = agent.page
  # 住所
  address = main_page.search('//*[@id="askTheaterPageLink"]/table/tr[1]/td/text()').inner_text
  # 上映中（予定)の映画情報をすべて取得
  all_movies = agent.page.search("div[@class='movie']")
  all_movies.each {|movie|
    # 映画のタイトル
    title = movie.search("h2").inner_text
    # 映画の詳細情報ページを取得
    info_link = movie.search('h2').search('a')[0]["href"]
    info_page = agent.get(movie_walker_plus_url + info_link)
    # 映画概略(description)
    description = info_page.search('//*[@id="mainInfo"]/p/text()').inner_text
    if (description == "")
      description = info_page.search('//*[@id="mainInfoNoImage"]/p/text()').inner_text
    end
    if (description == "")
      puts "infomeation of " + title + "@" + theater_name + " missing"
    end
    # 映画上映時間（長さ）
    runtime = info_page.search('//*[@id="infoBox"]/table/tr[4]/td/span').inner_text
    if runtime == ""
      runtime = info_page.search('//*[@id="infoBox"]/table/tr[5]/td/span').inner_text
    end
    if runtime == ""
      runtime = info_page.search('//*[@id="infoBox"]/table/tr[3]/td/span').inner_text
    end
    if runtime == ""
      puts 'runtime of "' + title + "@" + theater_name + '" missing.'
    end
    # スケジュール詳細ページを取得
    schedule = Hash.new
    schedule_link = movie.search("a").last['href']
    schedule_page = agent.get(movie_walker_plus_url + schedule_link)
    schedule_page.search('//*[@id="pageHeaderWrap"]/div[2]/div[2]/table').each {|schedule_table|
      schedule_table.xpath('tr')[0].xpath('th').each {|th|
        schedule[th["class"]] = th.inner_text
      }
      schedule_table.xpath('tr')[2].xpath('td').each {|td|
        week_day = td["class"].split(" ")[0]
        schedule[schedule[week_day]] = td.inner_text.gsub(/\(.*\)/,'').split(" ")
        schedule.delete(week_day)
      }
    }
    schedule.each {|day, showtimes|
      day = day.split("/")
      showtimes.each {|time|
        next if time.index("劇場問合") != nil || time == ""
        time = time.split(":")
        midnight = false
        if time[0].to_i >= 24
          time[0] = (time[0].to_i - 24).to_s
          midnight = true
        end
        cal.event do
          begin
            start_time = DateTime.new(2013, day[0].to_i, day[1].to_i, time[0].to_i, time[1].to_i)
            start_time = start_time + 1 if midnight
          rescue
            puts "crash at " + title + "@" + theater_name + "scheduling"
            next
          end
          end_time = start_time + Rational(1, 24 * 60) * runtime.to_i
          dtstart start_time, {'TZID' => 'Asia/Tokyo'}
          dtend end_time, {'TZID' => 'Asia/Tokyo'}
          summary title
          description description
          location address
        end
      }
    }
  }
  File.open(theater_name + ".ics", "w+b") { |f|
    f.write(cal.to_ical)
  }
}
