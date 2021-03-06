cat("\014") # Clear your console
rm(list = ls()) #clear your environment

########################## Load in header file ######################## #
setwd("~/git/of_dollars_and_data")
source(file.path(paste0(getwd(),"/header.R")))

########################## Load in Libraries ########################## #

library(scales)
library(readxl)
library(lubridate)
library(ggrepel)
library(ggjoy)
library(tidyverse)

folder_name <- "0139_individual_stocks"
out_path <- paste0(exportdir, folder_name)
dir.create(file.path(paste0(out_path)), showWarnings = FALSE)

########################## Start Program Here ######################### #

raw <- read.csv(paste0(importdir, "xxxx_sp500_individual_stocks/ycharts.csv"), skip = 6) %>%
  rename(symbol = Symbol,
         name = Name,
         metric = Metric) %>%
  gather(-symbol, -name, -metric, key=key, value=value) %>%
  mutate(year = as.numeric(gsub("X(\\d+)\\.(\\d+)\\.(\\d+)", "\\1", key, perl = TRUE))) %>%
  arrange(symbol, year) %>%
  filter(!is.na(value), year < 2019) %>%
  mutate(ret = value/lag(value) - 1) %>%
  filter(!is.na(ret)) %>%
  select(year, symbol, name, ret) 

n_years_data <- raw %>%
          group_by(symbol) %>%
          summarize(n_obs = n()) %>%
          ungroup() %>%
          select(symbol, n_obs)

full_data <- filter(n_years_data, n_obs == max(n_years_data$n_obs)) %>%
              select(symbol)

# Simulation parameters
n_simulations <- 1000
portfolio_sizes <- c(5, 10, 20, 30, 50, 100, 200, 300)
set.seed(12345)

final_results <- data.frame(year = c(), 
                            mean_ret = c(),
                            binned_ret = c(),
                            simulation = c(),
                            portfolio_size = c())

for(p in portfolio_sizes){
  print(p)
  for(i in 1:n_simulations){
    s <- sample(full_data$symbol, p, replace = FALSE)
    
    tmp <- raw %>%
            filter(symbol %in% s) %>%
            group_by(year) %>%
            summarize(mean_ret = mean(ret)) %>%
            ungroup() %>%
            mutate(binned_ret = case_when(
              mean_ret > 0.5 ~ 0.5,
              mean_ret < -0.5 ~ -0.5,
              TRUE ~ mean_ret
            ),
                    simulation = i,
                   portfolio_size = p
                   )
    
    if(p == portfolio_sizes[1] & i == 1){
      final_results <- tmp
    } else{
      final_results <- bind_rows(final_results, tmp)
    }
  }
}

overall_summary <- final_results %>%
                      group_by(year, portfolio_size) %>%
                      summarize(avg_ret = mean(mean_ret),
                                sd_ret = sd(mean_ret)) %>%
                      ungroup()

# Plot by portfolio size
for(p in portfolio_sizes){
  p_string <- str_pad(p, 3, pad = "0")
  
  to_plot <- final_results %>%
                filter(portfolio_size == p)
  
  source_string <- paste0("Source:  YCharts (OfDollarsAndData.com)")
  note_string   <- str_wrap(paste0("Note:  Stocks are selected from the S&P 500 and only include those with data for all years.  Returns shown exclude dividends."), 
                            width = 85)
  
  file_path <- paste0(out_path, "/dist_returns_portfolio_", p_string, "_stocks.jpeg")

  plot <- ggplot(data = to_plot, aes(x=binned_ret, y=as.factor(year))) +
    geom_joy_gradient(rel_min_height = 0.01, scale = 3, fill = "blue") +
    scale_x_continuous(label = percent, limit = c(-0.5, 0.5), breaks = seq(-0.5, 0.5, 0.25)) +
    of_dollars_and_data_theme +
    ggtitle(paste0("Return Distribution by Year\n", p, "-Stock Portfolio")) +
    labs(x = "1-Year Return", y = "Year",
         caption = paste0(source_string, "\n", note_string))
  
  ggsave(file_path, plot, width = 15, height = 12, units = "cm")
}

create_gif(out_path,
           paste0("dist_returns_portfolio_*.jpeg"),
           100,
           0,
           paste0("_gif_dist_portfolio_size_returns.gif"))


# ############################  End  ################################## #