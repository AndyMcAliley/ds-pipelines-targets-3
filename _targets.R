
library(targets)
library(tarchetypes)
library(tibble)
suppressPackageStartupMessages(library(dplyr))

options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "dataRetrieval", "urbnmapr",
                            "rnaturalearth", "cowplot", "lubridate",
                            "leaflet", "leafpop", "htmlwidgets"))

# Load functions needed by targets below
source("1_fetch/src/find_oldest_sites.R")
source("1_fetch/src/get_site_data.R")
source("2_process/src/tally_site_obs.R")
source("2_process/src/summarize_targets.R")
source("3_visualize/src/map_sites.R")
source("3_visualize/src/plot_site_data.R")
source("3_visualize/src/plot_data_coverage.R")
source("3_visualize/src/map_timeseries.R")

# Configuration
# states <- c('WI','MN','MI', 'IL', 'IN')
states <- c('WI','MN','MI', 'IL', 'IN', 'IA')
parameter <- c('00060')

# Pull site data
mapped_by_state_targets <- tar_map(
  values = tibble(state_abb = states) %>% 
    mutate(state_plot_files = sprintf("3_visualize/out/timeseries_%s.png", state_abb)),
  names = state_abb,
  unlist = FALSE,
  # split oldest_active_sites by state
  tar_target(nwis_inventory, filter(oldest_active_sites, state_cd == state_abb)),
  # download site data
  tar_target(nwis_data, get_site_data(nwis_inventory, state_abb, parameter)),
  # tally data
  tar_target(tally, tally_site_obs(nwis_data)),
  # plot data
  tar_target(timeseries_png,
             plot_site_data(state_plot_files, nwis_data, parameter),
             format = "file")
)

# Targets
list(
  # Identify oldest sites
  tar_target(oldest_active_sites, find_oldest_sites(states, parameter)),
  # Pull site data, tally, and plot
  mapped_by_state_targets,
  # Combine tallies
  tar_combine(obs_tallies, mapped_by_state_targets[[3]], command = combine_obs_tallies(!!!.x)),
  # Summarize targets
  tar_combine(summary_state_timeseries_csv, 
              mapped_by_state_targets[[4]], 
              command = summarize_targets('3_visualize/log/summary_state_timeseries.csv', !!!.x), 
              format="file"),
  # Plot data coverage
  tar_target(data_coverage_png, 
             plot_data_coverage(obs_tallies, "3_visualize/out/data_coverage.png", parameter),
             format = "file"),
  # Map oldest sites
  tar_target(site_map_png, 
             map_sites("3_visualize/out/site_map.png", oldest_active_sites), 
             format = "file"),
  # Interactive map of oldest sites, with timeseries plots
  tar_target(timeseries_map_html,
             map_timeseries(site_info = oldest_active_sites,
                            plot_info_csv = summary_state_timeseries_csv,
                            out_file = "3_visualize/out/timeseries_map.html"),
             format = "file")
)
