#----------- Used Libraries ---------------#
library(readr)
library(dplyr)
library(lubridate)
library(tidyr)

#------------ Handling Weather Data --------#
# Define cities
cities <- c("berlin", "hamburg", "frankfurt", "cologne", "munich")

# Loop over each city
for (city in cities) {
  message("Processing: ", city)
  
  # Construct file name
  file_name <- paste0(city, "_weather.txt")
  
  # Load city weather data
  df <- read_delim(file_name, delim = ";", show_col_types = FALSE)
  
  # Convert MESS_DATUM to datetime
  df <- df %>%
    mutate(timestamp_iso = ymd_h(MESS_DATUM))
  
  # Replace -999 with NA
  df <- df %>%
    mutate(TT_TU = ifelse(TT_TU == -999, NA, TT_TU))
  
  # Generate full hourly time range
  full_range <- data.frame(timestamp_iso = seq(min(df$timestamp_iso), max(df$timestamp_iso), by = "hour"))
  
  # Merge with full range to find missing rows
  df_full <- full_join(full_range, df, by = "timestamp_iso")
  
  # Fill TT_TU missing values with mean
  mean_temp <- mean(df$TT_TU, na.rm = TRUE)
  df_full <- df_full %>%
    mutate(TT_TU = ifelse(is.na(TT_TU), mean_temp, TT_TU))
  
  # Fill other columns
  df_full <- df_full %>%
    arrange(timestamp_iso) %>%
    fill(STATIONS_ID, .direction = "down") %>%
    mutate(
      QN_9 = ifelse(is.na(QN_9), 9, QN_9),
      RF_TU = ifelse(is.na(RF_TU), mean(df$RF_TU, na.rm = TRUE), RF_TU),
      eor = ifelse(is.na(eor), "eor", eor)
    )
  
  # Recreate MESS_DATUM and ISO timestamp
  df_full <- df_full %>%
    mutate(
      MESS_DATUM = format(timestamp_iso, "%Y%m%d%H"),
      timestamp = format(timestamp_iso, "%Y-%m-%dT%H:%M:%SZ")
    )
  
  # Save the filled dataset
  output_file <- paste0("imputed_", city, ".csv")
  write_delim(
    df_full %>% select(STATIONS_ID, MESS_DATUM, QN_9, TT_TU, RF_TU, eor),
    output_file,
    delim = ";"
  )
}

