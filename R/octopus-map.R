# Map Australia's fuel imports by supplier, and where the crude oil behind them was produced, from the raw APS and UN Comtrade files. Run from the project folder: Rscript R/octopus-map.R

library(tidyverse)
library(readxl)
library(jsonlite)

# ---- Colours ----
col_orange     <- "#EF7900"
col_darkorange <- "#D4582A"
col_red        <- "#A1253E"
col_darkred    <- "#611633"
col_yellow     <- "#F5B50C"
col_grey1      <- "#D9D9D9"
col_grey3      <- "#828282"
col_grey4      <- "#575757"
col_black      <- "#000000"

# ---- Read data ----
APS <- "data/raw/aps/australian-petroleum-statistics-data-extract-august-2026.xlsx"
COMTRADE <- "data/raw/comtrade"

# Persian Gulf producers, as named by both APS and Comtrade
GULF <- c("Saudi Arabia", "United Arab Emirates", "Iraq", "Kuwait", "Qatar", "Iran", "Oman", "Bahrain")

# The eight main refined fuel suppliers: map name, APS name and Comtrade file (Taiwan's latest is 2024)
SUPPLIERS <- tribble(
  ~supplier,     ~aps_name,                          ~file,
  "Singapore",   "Singapore",                        "comtrade_2709_imports_singapore_2025.json",
  "South Korea", "Korea, Republic of (South)",       "comtrade_2709_imports_south_korea_2025.json",
  "Malaysia",    "Malaysia",                         "comtrade_2709_imports_malaysia_2025.json",
  "Taiwan",      "Taiwan",                           "comtrade_2709_imports_taiwan_2024.json",
  "India",       "India",                            "comtrade_2709_imports_india_2025.json",
  "China",       "China (excludes SARs and Taiwan)", "comtrade_2709_imports_china_2025.json",
  "Brunei",      "Brunei Darussalam",                "comtrade_2709_imports_brunei_2025.json",
  "Japan",       "Japan",                            "comtrade_2709_imports_japan_2025.json"
)

# Crude imported straight to Australia: origins over 1,000 ML in 2025 and the crude source each counts as
DIRECT_CRUDE <- tribble(
  ~origin,         ~aps_name,                  ~crude_source,
  "Brunei",        "Brunei Darussalam",        "Other",
  "Malaysia",      "Malaysia",                 "Other",
  "United States", "United States of America", "United States",
  "Vietnam",       "Vietnam",                  "Other"
)

# APS: calendar 2025 imports by source country, ML. Refined imports are petrol, jet fuel and diesel only
aps <- read_excel(APS, sheet = "Imports volume by country") %>%
  filter(format(Month, "%Y") == "2025") %>%
  group_by(country = `Source country`) %>%
  summarise(crude   = sum(`Crude oil & other refinery feedstocks (ML)`),
            petrol  = sum(`Automotive gasoline (ML)`),
            jet     = sum(`Aviation turbine fuel (ML)`),
            diesel  = sum(`Diesel oil (ML)`)) %>%
  mutate(refined = petrol + jet + diesel)

# Comtrade: each supplier's crude oil imports (HS 2709) by country of origin, net weight in kg
read_comtrade <- function(file, supplier) {
  fromJSON(file.path(COMTRADE, file))$data %>%
    as_tibble() %>%
    filter(partnerCode != 0) %>%                 # drop the World total
    transmute(supplier, crude_data_year = refYear, country = partnerDesc,
              kg = coalesce(netWgt, 0))
}
supplier_crude <- bind_rows(map2(SUPPLIERS$file, SUPPLIERS$supplier, read_comtrade))

# Each supplier's crude shares by source, per cent of weight
crude_shares <- supplier_crude %>%
  group_by(supplier, crude_data_year) %>%
  summarise(gulf_share_pct   = 100 * sum(kg[country %in% GULF]) / sum(kg),
            russia_share_pct = 100 * sum(kg[country == "Russian Federation"]) / sum(kg),
            us_share_pct     = 100 * sum(kg[country == "USA"]) / sum(kg),
            .groups = "drop") %>%
  mutate(other_share_pct = 100 - gulf_share_pct - russia_share_pct - us_share_pct)

# The eight suppliers: refined imports, share of Australia's refined imports and crude shares
suppliers <- SUPPLIERS %>%
  left_join(aps, by = c(aps_name = "country")) %>%
  transmute(supplier, petrol_ML = petrol, jet_ML = jet, diesel_ML = diesel,
            refined_imports_ML = refined,
            share_of_aus_refined_imports_pct = 100 * refined / sum(aps$refined)) %>%
  left_join(crude_shares, by = "supplier")

# Imports straight to Australia. Refined fuel from Persian Gulf countries counts as made from Gulf crude;
# refined fuel from countries outside the eight suppliers and the Gulf counts as other countries
gulf_crude <- sum(aps$crude[aps$country %in% GULF])
gulf_refined <- sum(aps$refined[aps$country %in% GULF])
direct_named <- DIRECT_CRUDE %>%
  left_join(aps, by = c(aps_name = "country")) %>%
  transmute(origin, crude_source, flow = "crude", ML = crude)
direct <- bind_rows(
  direct_named,
  tibble(origin = "Persian Gulf", crude_source = "Persian Gulf", flow = "crude", ML = gulf_crude),
  tibble(origin = "Other sources", crude_source = "Other", flow = "crude",
         ML = sum(aps$crude) - sum(direct_named$ML) - gulf_crude),
  tibble(origin = "Persian Gulf", crude_source = "Persian Gulf", flow = "refined", ML = gulf_refined),
  tibble(origin = "Other sources", crude_source = "Other", flow = "refined",
         ML = sum(aps$refined) - sum(suppliers$refined_imports_ML) - gulf_refined)
)

# Approximate location of each supplier's main export refineries, and label positions
locations <- tribble(
  ~supplier,     ~lon,  ~lat, ~lx,   ~ly,  ~hj,
  "Singapore",   103.8,  1.3, 104.5, -2.2, 0,
  "South Korea", 129.3, 35.5, 127.5, 38.6, 1,
  "Malaysia",    101.0,  4.2,  99.5,  5.2, 1,
  "Taiwan",      120.2, 23.8, 118.5, 25.6, 1,
  "India",        70.0, 22.4,  68.5, 25.0, 1,
  "China",       121.5, 31.0, 119.5, 32.8, 1,
  "Brunei",      114.9,  4.9, 115.5,  8.0, 0.5,
  "Japan",       137.0, 35.0, 138.5, 32.2, 0,
  "Vietnam",     107.5, 10.3, 109.0, 12.5, 0
)

sources <- tribble(
  ~source,          ~src_lon, ~src_lat,
  "Persian Gulf",       51.5,     26.5,
  "Russia",             58.0,     57.0,
  "United States",     264.6,     29.7,
  "Other",              52.0,    -34.0
)

australia <- c(lon = 134, lat = -24)

source_cols <- c("Persian Gulf" = col_red,
                 "United States" = col_yellow,
                 "Russia" = col_darkred,
                 "Other" = col_grey3)

# ---- Build flows, in millions of litres ----
suppliers <- suppliers %>% left_join(locations, by = "supplier")

crude_to_suppliers <- suppliers %>%
  transmute(supplier, lon, lat,
            `Persian Gulf` = refined_imports_ML * gulf_share_pct / 100,
            Russia = refined_imports_ML * russia_share_pct / 100,
            `United States` = refined_imports_ML * us_share_pct / 100,
            Other = refined_imports_ML * other_share_pct / 100) %>%
  pivot_longer(-c(supplier, lon, lat), names_to = "source", values_to = "ML") %>%
  filter(ML > 150) %>%
  left_join(sources, by = "source")

# Crude imported straight to Australian refineries starts at the producing country where shown
crude_to_australia <- direct %>%
  filter(flow == "crude", ML > 150) %>%
  left_join(locations %>% select(origin = supplier, lon, lat), by = "origin") %>%
  left_join(sources %>% rename(crude_source = source), by = "crude_source") %>%
  mutate(lon = coalesce(lon, src_lon), lat = coalesce(lat, src_lat),
         source = crude_source, supplier = origin,
         alon = australia["lon"], alat = australia["lat"])

refined_to_australia <- bind_rows(
  suppliers %>% select(supplier, lon, lat, ML = refined_imports_ML),
  # Refined fuel imported directly starts at its crude source: the Persian Gulf, or other countries
  direct %>%
    filter(flow == "refined", ML > 150) %>%
    left_join(sources, by = c(crude_source = "source")) %>%
    transmute(supplier = origin, lon = src_lon, lat = src_lat, ML)
) %>%
  mutate(alon = australia["lon"], alat = australia["lat"])

# Share of the crude behind all fuel imports, by source. Refined imports from Persian Gulf countries count as Gulf crude, and from other countries outside the main suppliers as other countries
source_shares <- suppliers %>%
  transmute(`Persian Gulf` = refined_imports_ML * gulf_share_pct / 100,
            Russia = refined_imports_ML * russia_share_pct / 100,
            `United States` = refined_imports_ML * us_share_pct / 100,
            Other = refined_imports_ML * other_share_pct / 100) %>%
  pivot_longer(everything(), names_to = "source", values_to = "ML") %>%
  bind_rows(direct %>% select(source = crude_source, ML)) %>%
  group_by(source) %>%
  summarise(ML = sum(ML)) %>%
  mutate(share_pct = 100 * ML / sum(ML))

source_pct <- source_shares %>%
  transmute(source, pct = paste0(round(share_pct), "%")) %>%
  deframe()

# Quadratic Bezier curve between two points, bowed to one side
curve_path <- function(x0, y0, x1, y1, bend, n = 60) {
  cx <- (x0 + x1) / 2 - bend * (y1 - y0)
  cy <- (y0 + y1) / 2 + bend * (x1 - x0)
  t <- seq(0, 1, length.out = n)
  tibble(x = (1 - t)^2 * x0 + 2 * (1 - t) * t * cx + t^2 * x1,
         y = (1 - t)^2 * y0 + 2 * (1 - t) * t * cy + t^2 * y1)
}

make_paths <- function(df, x0, y0, x1, y1, bend) {
  df %>%
    mutate(path = pmap(list(.data[[x0]], .data[[y0]], .data[[x1]], .data[[y1]]),
                       curve_path, bend = bend)) %>%
    unnest(path)
}

crude_paths <- bind_rows(
  make_paths(filter(crude_to_suppliers, source != "United States"),
             "src_lon", "src_lat", "lon", "lat", 0.18),
  make_paths(filter(crude_to_suppliers, source == "United States"),
             "src_lon", "src_lat", "lon", "lat", -0.08),
  make_paths(crude_to_australia, "lon", "lat", "alon", "alat", 0.12)
) %>%
  mutate(group = paste(source, supplier, lon, lat))

refined_paths <- make_paths(refined_to_australia, "lon", "lat", "alon", "alat", -0.15)

# ---- Plot ----
# Pacific-centred world map so the United States sits east of Asia
# Keep only countries in the map frame, and every third point, so the chart stays light enough to save
world <- map_data("world2") %>%
  group_by(group) %>%
  filter(max(long) >= 40, min(long) <= 275, max(lat) >= -42, min(lat) <= 64, n() >= 20) %>%
  filter(row_number() %% 3 == 1 | row_number() == n()) %>%
  ungroup()

label_bg <- alpha("white", 0.8)

octopus_map <- ggplot() +
  geom_polygon(data = world, aes(long, lat, group = group),
               fill = col_grey1, colour = "white", linewidth = 0.2) +
  geom_path(data = crude_paths,
            aes(x, y, group = group, colour = source, linewidth = ML),
            lineend = "butt", linejoin = "round") +
  geom_path(data = refined_paths,
            aes(x, y, group = supplier, linewidth = ML),
            colour = col_orange, lineend = "butt", linejoin = "round") +
  geom_point(aes(australia["lon"], australia["lat"]), size = 8, colour = col_darkorange) +
  geom_point(data = locations, aes(lon, lat), size = 3, colour = col_grey4) +
  geom_point(data = sources, aes(src_lon, src_lat, fill = source),
             size = 5, shape = 21, colour = "white") +
  geom_label(data = suppliers,
             aes(lx, ly, hjust = hj,
                 label = paste0(supplier, " ", floor(share_of_aus_refined_imports_pct + 0.5), "%")),
             size = 16 / .pt, colour = col_black,
             fill = label_bg, linewidth = 0, label.padding = unit(1, "mm")) +
  annotate("label", x = 109, y = 12.5, label = "Vietnam", hjust = 0, size = 16 / .pt,
           colour = col_black, fill = label_bg, linewidth = 0, label.padding = unit(1, "mm")) +
  annotate("label", x = 42, y = 19, hjust = 0, vjust = 1, lineheight = 0.9, size = 18 / .pt,
           label = paste0("Crude from the\nPersian Gulf ", source_pct["Persian Gulf"]),
           colour = col_red, fill = label_bg, linewidth = 0, label.padding = unit(1, "mm")) +
  annotate("label", x = 43, y = 61, hjust = 0, size = 18 / .pt,
           label = paste("Crude from Russia", source_pct["Russia"]),
           colour = col_darkred, fill = label_bg, linewidth = 0, label.padding = unit(1, "mm")) +
  annotate("label", x = 273, y = 35, hjust = 1, vjust = 0, lineheight = 0.9, size = 18 / .pt,
           label = paste("Crude from the US", source_pct["United States"]),
           colour = col_yellow, fill = label_bg, linewidth = 0, label.padding = unit(1, "mm")) +
  annotate("text", x = 49, y = -38.5, hjust = 0, size = 18 / .pt,
           label = paste("All other countries", source_pct["Other"]), colour = col_grey3) +
  annotate("text", x = 141, y = -28, size = 18 / .pt, label = "Australia", colour = col_darkorange) +
  annotate("curve", x = 140, y = 6, xend = 132, yend = 4.5, curvature = 0.25,
           colour = col_orange, linewidth = 0.4,
           arrow = arrow(length = unit(1.5, "mm"), type = "closed")) +
  annotate("text", x = 141, y = 6.5, hjust = 0, size = 16 / .pt, lineheight = 0.9,
           label = "Refined fuel\nimports", colour = col_orange) +
  scale_colour_manual(values = source_cols) +
  scale_fill_manual(values = source_cols) +
  scale_linewidth(range = c(0.5, 9)) +
  coord_fixed(ratio = 1.1, xlim = c(40, 275), ylim = c(-42, 64), expand = FALSE) +
  labs(
    title = "Australia buys fuel from many countries, but more than half of it is made from Gulf crude",
    subtitle = "Australia's petrol, jet fuel and diesel imports by supplier and share, and where the crude oil behind them was produced, 2025",
    caption = str_wrap(paste(
      "Notes: Refined fuel imports are petrol, jet fuel and diesel. Line width shows volume. Crude lines into each supplier split Australia's",
      "refined fuel imports from that supplier by where the supplier sources its crude oil. Crude lines into Australia show crude imported",
      "directly for Australian refineries. Refined fuel imported directly from Persian Gulf countries is counted as made from Gulf crude.",
      "Percentages next to each crude source show its share of the crude behind all of Australia's fuel imports.",
      "Flows under 150 million litres are not shown. Taiwan crude data are for 2024.",
      "Persian Gulf includes Saudi Arabia, UAE, Iraq, Kuwait, Qatar, Iran, Oman and Bahrain.",
      "Source: Grattan analysis of DCCEEW (2026), Australian Petroleum Statistics; UN Comtrade (2026)."), width = 215)
  ) +
  theme_void(base_size = 18) +
  theme(
    plot.title = element_text(face = "bold", size = 24, margin = margin(b = 6)),
    plot.subtitle = element_text(margin = margin(b = 10)),
    plot.caption = element_text(hjust = 0, size = 11, colour = col_grey4, lineheight = 1.1, margin = margin(t = 10)),
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.background = element_rect(fill = "white", colour = NA),
    plot.margin = margin(12, 12, 12, 12),
    legend.position = "none"
  )

# ---- Save ----
dir.create("atlas", showWarnings = FALSE)
ggsave("atlas/octopus-map.pdf", octopus_map, width = 44.32, height = 22.16, units = "cm")
