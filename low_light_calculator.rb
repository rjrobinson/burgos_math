require 'active_support/time'
require 'active_support/all'
require 'csv'
require 'date'
require 'json'

class LowLightCalculator

  attr_reader :schedule

  def initialize(sunrise_sunset_data_file_name = "sunrise_sunset_unix.csv")
    @sunrise_sunset_data_file_name = sunrise_sunset_data_file_name
    @schedule = generate_shift_schedule
    Time.zone = ActiveSupport::TimeZone.new('America/New_York')
  end

  def run
    calculate_low_light_hours_per_shift
  end

  # Define the shift start and end times
  def shift_start_times
    [
      DateTime.parse('06:30'),
      DateTime.parse('14:30'),
      DateTime.parse('22:30')
    ]
  end

  def shift_end_times
    [
      DateTime.parse('14:30'),
      DateTime.parse('22:30'),
      DateTime.parse('06:30') + 1.day
    ]
  end

  def starting_date
    Time.parse(sunrise_sunset_data.first[:date])
  end

  def ending_date
    Time.parse(sunrise_sunset_data.last[:date])
  end

  def sunrise_sunset_data
    @sunrise_sunset_data ||= load_sunrise_sunset_data
  end

  def load_sunrise_sunset_data
    data = []
    CSV.foreach(@sunrise_sunset_data_file_name) do |row|
      date, sunset, sunrise = row
      data << { date: date, sunrise: sunrise, sunset: sunset }
    end
    data.shift
    convert_to_est(data)
    data
  end

  def convert_to_est(data)
    data = data.map do |row|

      sunrise_est = ((force_time(Time.at(row[:sunrise].to_i).utc)) - 1.hour) - 30.minutes
      sunset_est = ((force_time(Time.at(row[:sunset].to_i).utc)) - 1.hour) - 30.minutes
      row[:date] = force_time(Time.at(row[:sunset].to_i).utc).strftime('%Y-%m-%d')
      row[:sunrise] = sunrise_est.strftime('%H:%M:%S')
      row[:sunset] = sunset_est.strftime('%H:%M:%S')
    end
    data
  end

  def force_time(t)
    Time.new(t.year, t.month, t.day, t.hour, t.min, t.sec, '-05:00').in_time_zone('Eastern Time (US & Canada)')
  end

  def lookup_sunrise_sunset(date)
    data = sunrise_sunset_data.find { |d| d[:date] == date }
    raise "No sunrise/sunset data found for #{date}" if data.nil?

    sunrise = data[:sunrise]
    sunset = data[:sunset]
    { sunrise: sunrise, sunset: sunset }
  rescue
    { sunrise: nil, sunset: nil }
  end

  def calculate_overlap_hours(start_time_1, end_time_1, start_time_2, end_time_2)
    # Check for overlap on the first day
    max_start_time_1 = start_time_1
    min_end_time_1 = [end_time_1, start_time_1 + 1.day].min
    overlap_hours_1 = [(min_end_time_1 - max_start_time_1) / 3600.0, 0].max

    # Check for overlap on the second day
    max_start_time_2 = [start_time_2, end_time_1].max
    min_end_time_2 = end_time_2
    overlap_hours_2 = [(min_end_time_2 - max_start_time_2) / 3600.0, 0].max

    # Return the total overlap duration
    overlap_hours_1 + overlap_hours_2
  end

  def calculate_low_light_hours_per_shift
    low_light_hours_per_shift = {}

    schedule.each do |shift|
      start_time = force_time shift[:start_time]
      end_time = force_time shift[:end_time]

      sunrise_row = sunrise_sunset_data.find { |row| row[:date] == end_time.strftime('%Y-%m-%d') }

      first_sunrise = Time.parse(start_time.strftime('%Y-%m-%d') + " " + sunrise_row[:sunrise])
      first_sunset = Time.parse(start_time.strftime('%Y-%m-%d') + " " + sunrise_row[:sunset])

      second_sunrise = nil
      if start_time > first_sunset
        second_sunrise_row = sunrise_sunset_data.find { |row| row[:date] == end_time.strftime('%Y-%m-%d') }
        second_sunrise = Time.parse(end_time.strftime('%Y-%m-%d') + " " + second_sunrise_row[:sunrise])
      end

      darkness = case shift[:start_time].strftime('%H:%M:%S')
                 when '06:30:00'
                   shift_1(start_time, end_time, first_sunrise, first_sunset)
                 when '14:30:00'
                   shift_2(start_time, end_time, first_sunset)
                 when '22:30:00'
                   shift_3(start_time, end_time, second_sunrise)
                 end

      low_light_hours_per_shift[shift] = { start_time: start_time,
                                           end_time: end_time,
                                           first_sunrise: first_sunrise,
                                           first_sunset: first_sunset,
                                           second_sunrise: second_sunrise,
                                           darkness: darkness
      }
    rescue
      nil
    end

    low_light_hours_per_shift
  end

  def shift_1(start_time, end_time, sunrise, sunset)
    darkness = 0.0
    if start_time < sunrise
      darkness += max_length(sunrise, start_time)
    end

    if start_time < sunset && end_time > sunset
      darkness += max_length(sunset, end_time)
    end

    [darkness, 480].min
  end

  def shift_2(start_time, end_time, sunset)
    darkness = 0.0
    if start_time < sunset
      darkness += max_length(sunset, end_time)
    end

    [darkness, 480].min
  end

  def shift_3(start_time, end_shift, next_sunrise)
    [max_length(start_time, [end_shift, next_sunrise].min), 480].min
  end

  def group_low_light_hours_by_start_time(csv_filename = 'low_light_hours.csv')
    low_light_hours_by_start_time = { 'A' => [], 'B' => [], 'C' => [] }

    CSV.foreach(csv_filename, headers: true) do |row|
      start_time_str = row['Start Time']
      start_time = DateTime.parse(start_time_str)

      if start_time.hour < 8
        low_light_hours_by_start_time['A'] << row.to_h
      elsif start_time.hour < 16
        low_light_hours_by_start_time['B'] << row.to_h
      else
        low_light_hours_by_start_time['C'] << row.to_h
      end
    end

    low_light_hours_by_start_time
  end

  def to_csv(filename = 'low_light_hours.csv')
    CSV.open(filename, 'wb') do |csv|
      csv << ["DATE", 'shift start time', 'shift end time', "first sunrise", "first sunset", "second_sunrise", 'Darkness (minutes)', "% of Shift"]
      calculate_low_light_hours_per_shift.each do |shift, info|
        date = shift.dig(:start_time)&.strftime('%Y-%m-%d')
        start_time = info.dig(:start_time)&.strftime('%H:%M:%S')
        end_time = info.dig(:end_time)&.strftime('%H:%M:%S')
        first_sunrise = info.dig(:first_sunrise)&.strftime('%H:%M:%S')
        first_sunset = info.dig(:first_sunset)&.strftime('%H:%M:%S')
        second_sunrise = info.dig(:second_sunrise)&.strftime('%Y-%m-%d %H:%M:%S')
        darkness = info[:darkness].round(1)
        percent_of_shift = ((darkness / 480) * 100).round(1)
        csv << [date, start_time, end_time, first_sunrise, first_sunset, second_sunrise, darkness, percent_of_shift]
      end
    end
  end

  private

  def max_length(a, b)
    minutes = ((a - b).abs) / 60
    minutes >= 480 ? 480 : minutes
  end

  def generate_shift_schedule
    schedule = []

    current_date = starting_date
    while current_date <= ending_date do
      shift_start_times.each_with_index do |start_time, index|
        shift_end_time = shift_end_times[index]
        shift_start = DateTime.new(current_date.year, current_date.month, current_date.day, start_time.hour, start_time.minute, start_time.second, start_time.offset)
        shift_end = DateTime.new(current_date.year, current_date.month, current_date.day, shift_end_time.hour, shift_end_time.minute, shift_end_time.second, shift_end_time.offset)
        if shift_end < shift_start
          shift_end += 1.day
        end
        schedule << { start_time: shift_start, end_time: shift_end }
      end
      current_date += 1.day
    end

    schedule
  end
end

# l = LowLightCalculator.new
# l.calculate_low_light_per_shift_per_day