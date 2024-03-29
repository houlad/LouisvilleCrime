library(ggmap)
library(dplyr)
library(ape)
library(readr)

# Read in raw data
raw_data <- read_csv("crime_lou_with_geocoding.csv")

# Scrape the official list of Louisville zip codes (does not include 
# the 'nonstandard' zip codes i.e. PO Box or business zip codes)
library(rvest)
html <- read_html("http://kentucky.hometownlocator.com/zip-codes/zipcodes,city,louisville.cfm")
zips <- html_nodes(html, "tr:nth-child(3) a")
zips <- html_text(zips)

# Geocode all Louisville zip codes 
zip_cords <- data.frame(zips = factor(), lng = numeric(), lat = numeric())
for(z in zips){
  temp_cords <- geocode(z, source = 'google')
  temp_df <- data.frame(zips = z, lng = temp_cords[1], lat = temp_cords[2])
  zip_cords <- rbind(zip_cords, temp_df)
}

# Function creates useful date variables
create_date_variables <- function(df){
  require(lubridate)
  # Uses the POSIXct date_occured variable to create useful date related
  # subvariables
  df$year <- year(df$date_occured)
  df$month <- month(df$date_occured)
  df$day <- day(df$date_occured)
  df$hour <- hour(df$date_occured)
  df$year_month <- paste(df$year, df$month, sep = '-')
  df$day_of_week <- wday(df$date_occured, label = TRUE, abbr = FALSE)
  df$weekday <- ifelse(df$day_of_week == "Saturday" | df$day_of_week == "Sunday", 
                       "Weekend", "Weekday")
  df$yday <- yday(df$date_occured)
  df$date <- as.Date(df$date_occured)
  
  return(df)
}

crime <- create_date_variables(raw_data)

# Group crimes by zip code and aggregate counts. Then add geocoded lat/lng
crime_zip_agg <- crime%>%
  filter(year >=2005 & zip_code %in% zips)%>%
  group_by(zips = factor(zip_code))%>%
  summarise(count = n())

crime_zip_agg <- left_join(crime_zip_agg, zip_cords, by = 'zips')

#Moran I test for spatial autocorrelation; distance matrix must be generated first
zip_dists <- as.matrix(dist(cbind(crime_zip_agg$lon, crime_zip_agg$lat)))
#Take inverse and replace diag entries with zero
zip_dists_inv <- 1/zip_dists
diag(zip_dists_inv)<- 0

# Now we can calculate moran I statistic
Moran.I(crime_zip_agg$count, zip_dists_inv)

# p value is approx 1.242739e-11 indicating spatial autocorrelation
# This is as expected, but indicates that trying to model this data by time alone
# may not be fruitful
