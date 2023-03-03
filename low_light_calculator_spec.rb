require 'rspec'
require 'pry'
require_relative 'low_light_calculator'

RSpec.describe LowLightCalculator do
  subject(:l) { LowLightCalculator.new }

  describe '#load_sunrise_sunset_data' do
    context 'when given a valid sunrise/sunset data file' do
      it 'loads the sunrise and sunset data correctly' do
        calculator = LowLightCalculator.new('spec/support/test_sunrise_sunset_unix.csv')
        result = calculator.load_sunrise_sunset_data

        converted_data = []
        CSV.foreach("spec/support/test_sunrise_sunset_unix.csv") do |row|
          date, sunset, sunrise = row
          converted_data << { date: date, sunrise: sunrise, sunset: sunset }
        end

        converted_data.shift

        converted_data.map do |row|
          sunrise_est = force_time(Time.at(row[:sunrise].to_i).utc)
          sunset_est = force_time(Time.at(row[:sunset].to_i).utc)
          row[:date] = force_time(Time.at(row[:sunset].to_i).utc).strftime('%Y-%m-%d')
          row[:sunrise] = sunrise_est.strftime('%H:%M:%S')
          row[:sunset] = sunset_est.strftime('%H:%M:%S')
        end
        binding.pry
        expect(result).to eq(converted_data)
      end
    end
  end

  describe 'Sunrise/sunset data lookup' do
    it 'returns the correct sunrise/sunset data for a given date' do
      expected_result = { sunrise: '07:57:29', sunset: '20:34:00' }
      actual_result = l.lookup_sunrise_sunset('2022-03-03')

      expect(actual_result).to eq(expected_result)
    end

    it 'returns nil for sunrise/sunset data if the date is not found' do
      expected_result = { sunrise: nil, sunset: nil }
      actual_result = l.lookup_sunrise_sunset('2024-03-04')

      expect(actual_result).to eq(expected_result)
    end
  end

  describe '#shift_start_times' do
    it 'returns an array of shift start times in EST timezone' do
      expected_start_times = [
        DateTime.parse('06:30'),
        DateTime.parse('14:30'),
        DateTime.parse('22:30')
      ]
      expect(l.shift_start_times).to eq(expected_start_times)
    end
  end

  describe '#shift_end_times' do
    it 'returns an array of shift end times in EST timezone' do

      expected_end_times = [
        DateTime.parse('14:30'),
        DateTime.parse('22:30'),
        DateTime.parse('06:30') + 1.day
      ]
      expect(l.shift_end_times).to eq(expected_end_times)
    end
  end

  describe '#starting_date' do
    it 'returns the starting date in the sunrise/sunset data' do
      expected_starting_date = Date.parse('2022-03-04')
      expect(l.starting_date.to_date).to eq(expected_starting_date)
    end
  end

  describe '#ending_date' do
    it 'returns the ending date in the sunrise/sunset data' do

      expected_ending_date = Date.parse('2023-03-02')
      expect(l.ending_date.to_date).to eq(expected_ending_date)
    end
  end

  describe '#sunrise_sunset_data' do
    it 'returns an array of sunrise and sunset data' do
      expect(l.sunrise_sunset_data).to be_a(Array)
      expect(l.sunrise_sunset_data.first).to include(:date, :sunrise, :sunset)
    end
  end

  describe '#lookup_sunrise_sunset' do
    it 'returns the sunrise and sunset times for the given date' do

      date = '2022-03-03'
      expected_sunrise = DateTime.new(2022, 03, 03, 6, 30, 49, "-0500")
      expected_sunset = DateTime.new(2022, 03, 04, 0, 0, 0, "-0500")

      result = l.lookup_sunrise_sunset(date)
      expect(result[:sunrise]).to eq(expected_sunrise)

      # Convert expected sunset time to EST timezone
      expected_sunset_est = expected_sunset.in_time_zone('Eastern Time (US & Canada)').to_datetime
      expect(result[:sunset]).to eq(expected_sunset_est)
    end

    it 'raises an error if no sunrise/sunset data is found for the given date' do

      date = Date.parse('2021-01-01')
      expect { l.lookup_sunrise_sunset(date) }.to raise_error(RuntimeError)
    end
  end

  describe '#calculate_low_light_hours' do
    it 'returns the number of low light hours for the given date and shift' do

      date = '2022-03-06'
      shift_start = DateTime.parse('06:30')
      shift_end = DateTime.parse('14:30')
      expected_result = 1.75
      result = l.calculate_low_light_hours(date, shift_start, shift_end)
      expect(result).to eq(expected_result)
    end
  end

  def force_time(t)
    Time.new(t.year, t.month, t.day, t.hour, t.min, t.sec, '-05:00').in_time_zone('Eastern Time (US & Canada)')
  end

end