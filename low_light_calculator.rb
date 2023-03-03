require 'active_support/time'
require 'active_support/all'
require 'csv'
require 'date'
require 'json'

class LowLightCalculator

  def initialize(sunrise_sunset_data_file_name = "sunrise_sunset_unix.csv")
    @sunrise_sunset_data_file_name = sunrise_sunset_data_file_name
    Time.zone = ActiveSupport::TimeZone.new('America/New_York')
  end

  # @sunrise_sunset_data_file_name = "sunrise_sunset_unix.csv"

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
    sunrise_sunset_data.first[:date]
  end

  def ending_date
    sunrise_sunset_data.last[:date]
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
      sunrise_est = force_time(Time.at(row[:sunrise].to_i).utc)
      sunset_est = force_time(Time.at(row[:sunset].to_i).utc)
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

  def calculate_low_light_hours(date, shift_start, shift_end)
    # Convert times to Eastern Standard Time
    est = ActiveSupport::TimeZone.new('Eastern Time (US & Canada)')
    # Look up the sunrise and sunset times for the given date
    sunrise_sunset = lookup_sunrise_sunset(date)
    sunrise = sunrise_sunset[:sunrise]
    sunset = sunrise_sunset[:sunset]

    # Convert shift start and end times to Eastern Standard Time
    shift_start_est = shift_start.in_time_zone(est)
    shift_end_est = shift_end.in_time_zone(est)

    # Convert sunrise and sunset times to UTC timezone
    sunrise_est = sunrise.in_time_zone(est).utc.to_datetime
    sunset_est = sunset.in_time_zone(est).utc.to_datetime

    # Calculate the maximum number of low light hours for the shift
    max_low_light_hours = [(shift_end_est - shift_start_est) / 3600.0, 8.0].min

    # Determine the start and end times of the low light period
    sunrise_time_est = [sunrise_est, shift_start_est.to_datetime].max
    sunset_time_est = [sunset_est, shift_end_est.to_datetime].min

    # If the shift ends on the next day, adjust the sunset time to midnight
    if shift_end_est < shift_start_est
      sunset_time_est = est.parse('00:00:00').utc.to_datetime
    end

    # Calculate the number of low light hours for the shift
    low_light_hours = [sunset_time_est - sunrise_time_est, 0].max / 3600.0
    low_light_hours = [low_light_hours, max_low_light_hours].min
    low_light_hours = [low_light_hours, 8.0].min
    low_light_hours.abs
  end

  def calculate_low_light_per_shift_per_day(output_file = 'low_light_hours.csv')
    # Open the output file for writing
    CSV.open(output_file, 'w') do |csv|
      # Write the headers to the CSV file
      csv << ['Date', 'Shift 1 Low Light Hours', 'Shift 2 Low Light Hours', 'Shift 3 Low Light Hours']

      # Loop over each day in the sunrise/sunset data
      (starting_date..ending_date).each do |date|
        # Loop over each shift and calculate the low light hours
        shift_low_light_hours = shift_start_times.zip(shift_end_times).map do |(shift_start, shift_end)|
          binding.pry
          shift_start_date_time = date + shift_start.to_time.seconds_since_midnight.seconds
          shift_end_date_time = date + shift_end.to_time.seconds_since_midnight.seconds
          low_light_hours = calculate_low_light_hours(date.to_s, shift_start_date_time, shift_end_date_time)
          low_light_hours.round(2)
        end

        # Write the data to the CSV file
        row = [date.strftime('%Y-%m-%d')] + shift_low_light_hours
        csv << row
      end
    end
  end
end

# l = LowLightCalculator.new
# l.calculate_low_light_per_shift_per_day