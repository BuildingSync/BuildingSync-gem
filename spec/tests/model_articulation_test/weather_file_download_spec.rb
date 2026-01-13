# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'buildingsync/bcl_weather_file_downloader'

RSpec.describe 'WeatherFileDownload' do
  xit "download_weather_file_from_weather_id writes a weather file to disk" do
    # Action
    weather_filepath = BuildingSync::BCLWeatherFileDownloader.download_weather_file_from_weather_id("weather_station_id")

    # Assertion
    expect(File.exist?(weather_filepath)).to be true
  end

  it "download_weather_file_from_city_name writes a weather file to disk" do
    # Action
    weather_filepath = BuildingSync::BCLWeatherFileDownloader.download_weather_file_from_city_name("Denver", "CO")

    # Assertion
    expect(File.exist?(weather_filepath)).to be true
  end
end
