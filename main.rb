require 'csv'
require 'net/http'
require 'json'
require 'date'

# Replace with your OpenWeatherMap API key
api_key = "d1a2f1a73779f591f7465f105d44200d"

	latitude = "40.7895"
	longitude = "74.0565"

# Set the start and end dates for the query
start_date = Date.today - 365
end_date = Date.today - 1

# Open the CSV file for writing
CSV.open('sunrise_sunset.csv', 'wb') do |csv|
  # Loop over each day in the date range
  current_date = start_date
  while current_date <= end_date
    # Format the date for the API request
    query_date = current_date.strftime('%Y-%m-%d')

    # Make the API request
    url = URI("https://api.openweathermap.org/data/2.5/onecall?lat=#{latitude}&lon=#{longitude}&exclude=current,minutely,hourly,alerts&units=metric&appid=#{api_key}&dt=#{query_date}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    # Get the sunrise and sunset times for the day
    sunrise = Time.at(data['current']['sunrise']).strftime('%Y-%m-%d %H:%M:%S')
    sunset = Time.at(data['current']['sunset']).strftime('%Y-%m-%d %H:%M:%S')

    # Add the results to the CSV file
    csv << [query_date, sunrise, sunset]

    # Increment the current date
    current_date += 1
  end
end