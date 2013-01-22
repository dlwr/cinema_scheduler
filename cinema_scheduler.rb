# -*- coding: utf-8 -*-
require 'rubygems'
require 'icalendar'
require 'kconv'

class Integer
  def ordinalize
    suffix =
      if (fd=abs%10).between?(1,3) && !abs.between?(11,13)
        %w(_ st nd rd)[fd]
      else
        'th'
      end
    "#{self}" + suffix
  end
end

cal = Icalendar::Calendar.new

theater_name = ARGV[0].split(".")[0]
open(ARGV[0]) { |inFile|
  if theater_name.index("シネマヴェーラ渋谷") != nil
    location = theater_name + " 東京都渋谷区円山町1-5 Q-AXビル 4F"
  elsif theater_name.index("ヒューマントラストシネマ渋谷")
    location = theater_name + " 東京都渋谷区渋谷1-23−16 cocoti 7-8F‎"
  elsif theater_name.index("銀座シネパトス")
    location = theater_name + " 東京都中央区銀座4-8-7"
  elsif theater_name.index("ギンレイホール")
    location = theater_name + " 東京都新宿区神楽坂2-19 銀鈴会館 1Ｆ"
  elsif theater_name.index("キネカ大森")
    location = theater_name + " 東京都品川区南大井6-27-25"
  elsif theater_name.index("三軒茶屋シネマ")
    location = theater_name + " 東京都世田谷区三軒茶屋2-14-6"
  elsif theater_name.index("三軒茶屋中央劇場")
    location = theater_name + " 東京都世田谷区三軒茶屋2-14-5"
  elsif theater_name.index("早稲田松竹")
    location = theater_name + " 東京都新宿区高田馬場1-5-16"
  elsif theater_name.index("シネマ豊洲")
    location = theater_name + " 東京都江東区豊洲2-4-9 三井ショッピングパーク アーバンドック ららぽーと豊洲3F"
  else
    location = nil
  end

  while true
    begin
      title = inFile.gets.chop
      length = inFile.gets.to_i
      description = ""
      while (line = inFile.gets).index("descend") == nil
        description << line
      end
      while true
        release_date = inFile.gets.chop.split("/").map { |i| i.to_i }
        release_date.unshift(2013) if release_date.size == 2
        days = inFile.gets.to_i
        times = inFile.gets.to_i
        showtimes = []
        times.times { |i|
          showtimes << inFile.gets.chop.split(":").map { |i| i.to_i }
        }

        showtimes.each { |showtime|
          cal.event do
            startTime = DateTime.new(release_date[0], release_date[1], release_date[2],
                                 showtime[0], showtime[1])
            endTime = startTime + Rational(1, 24 * 60) * length
            dtstart startTime, {'TZID' => 'Asia/Tokyo'}
            dtend endTime, {'TZID' => 'Asia/Tokyo'}
            summary title
            description description
            location location
            add_rrule "FREQ=DAILY;COUNT=#{days}"
          end
        }
        break if inFile.gets.index("end")
      end
      break if inFile.gets.index("end")
    rescue
      p title
    else
    end
  end
}
File.open(theater_name + ".ics", "w+b") { |f|
  f.write(cal.to_ical)
}
