# Download the UN Comtrade crude oil import files that R/octopus-map.R reads. Run from the project folder: Rscript R/download_comtrade.R

# The eight main suppliers of refined fuel to Australia: file name, Comtrade reporter code and year (Taiwan reports as "Other Asia, nes" and its latest year is 2024)
REPORTERS <- data.frame(
  name = c("singapore", "south_korea", "malaysia", "taiwan", "india", "china", "brunei", "japan"),
  code = c(702, 410, 458, 490, 699, 156, 96, 392),
  year = c(2025, 2025, 2025, 2024, 2025, 2025, 2025, 2025)
)

dir.create("data/raw/comtrade", recursive = TRUE, showWarnings = FALSE)

# ---- Download imports of crude oil (HS 2709) by partner country ----
for (i in seq_len(nrow(REPORTERS))) {
  url <- paste0("https://comtradeapi.un.org/public/v1/preview/C/A/HS?reporterCode=", REPORTERS$code[i],
                "&period=", REPORTERS$year[i], "&cmdCode=2709&flowCode=M&includeDesc=true")
  file <- sprintf("data/raw/comtrade/comtrade_2709_imports_%s_%s.json", REPORTERS$name[i], REPORTERS$year[i])
  download.file(url, file, quiet = TRUE)
  Sys.sleep(2)  # the public API limits how often it can be called
}
