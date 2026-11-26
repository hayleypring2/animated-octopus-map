# Export the flows and curve geometry behind the octopus map, for animation/octopus_animate.py.
# Run from the project folder: Rscript R/export_flows.R
# Runs R/octopus-map.R up to the plot, so every figure is the same as on the static map
src <- readLines("R/octopus-map.R")
suppressMessages(eval(parse(text = src[seq_len(grep("^octopus_map <- ggplot", src) - 1)])))
dir.create("export", showWarnings = FALSE)
write_csv(crude_paths %>% select(group, source, supplier, ML, x, y), "export/crude_paths.csv")
write_csv(refined_paths %>% select(supplier, ML, x, y), "export/refined_paths.csv")
write_csv(suppliers %>% select(supplier, lon, lat, lx, ly, hj, share = share_of_aus_refined_imports_pct, refined_imports_ML), "export/suppliers.csv")
write_csv(sources, "export/sources.csv")
write_csv(locations, "export/locations.csv")
write_csv(source_shares, "export/source_shares.csv")
write_csv(world, "export/world.csv")
cols <- c(red=col_red, yellow=col_yellow, darkred=col_darkred, grey3=col_grey3, grey1=col_grey1, grey4=col_grey4, orange=col_orange, darkorange=col_darkorange, black=col_black)
write_csv(enframe(cols), "export/colours.csv")
