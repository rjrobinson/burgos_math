package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"time"
)

func main() {
	// Replace with your OpenWeatherMap API key
	apiKey := "d1a2f1a73779f591f7465f105d44200d"

	// Replace with the latitude and longitude of your location
	latitude := "40.7895"
	longitude := "74.0565"

	// Set the start and end dates for the query
	startDate := time.Now().AddDate(-1, 0, 0)
	endDate := time.Now().AddDate(0, 0, -1)

	// Open the CSV file for writing
	file, err := os.Create("sunrise_sunset.csv")
	if err != nil {
		panic(err)
	}
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush()

	// Loop over each day in the date range
	for date := startDate; date.Before(endDate); date = date.AddDate(0, 0, 1) {
		// Format the date for the API request
		queryDate := date.Format("2006-01-02")

		// Make the API request
		url := fmt.Sprintf("https://api.openweathermap.org/data/2.5/onecall?lat=%s&lon=%s&exclude=current,minutely,hourly,alerts&units=metric&appid=%s&dt=%s", latitude, longitude, apiKey, queryDate)
		response, err := http.Get(url)
		if err != nil {
			panic(err)
		}
		defer response.Body.Close()

		// Read the response body and parse the JSON data
		body, err := ioutil.ReadAll(response.Body)
		if err != nil {
			panic(err)
		}
		var data map[string]interface{}
		err = json.Unmarshal(body, &data)
		if err != nil {
			panic(err)
		}

		// Get the sunrise and sunset times for the day
		sunrise := time.Unix(int64(data["current"].(map[string]interface{})["sunrise"].(float64)), 0).Format("2006-01-02 15:04:05")
		sunset := time.Unix(int64(data["current"].(map[string]interface{})["sunset"].(float64)), 0).Format("2006-01-02 15:04:05")

		// Write the results to the CSV file
		err = writer.Write([]string{queryDate, sunrise, sunset})
		if err != nil {
			panic(err)
		}
	}
}
