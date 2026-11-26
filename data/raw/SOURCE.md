# Sources

## Australian Petroleum Statistics

| | |
|---|---|
| File | `aps/australian-petroleum-statistics-data-extract-august-2026.xlsx`, unchanged |
| Title | Australian Petroleum Statistics, data extract |
| Publisher | Department of Climate Change, Energy, the Environment and Water (DCCEEW), Canberra |
| Release | Data extract dated August 2026 (sheet `Index`, cell C4) |
| Sheet used | `Imports volume by country`: column A `Month`, B `Source country`, C `Crude oil & other refinery feedstocks (ML)`, E `Automotive gasoline (ML)`, G `Aviation turbine fuel (ML)`, I `Diesel oil (ML)`, N `Total refined petroleum products (ML)`. Calendar 2025 is rows 8227 to 8784. |
| Web | https://www.energy.gov.au/government-priorities/energy-data/australian-petroleum-statistics |
| Licence | Creative Commons Attribution 4.0 International (sheet `Copyright `) |
| Attribution | Australian Petroleum Statistics, Commonwealth of Australia 2026 |
| SHA-256 | `49805322f6d1d5a71bfd7d33bd3ec73eda0e4f4a066899d7f8904268adbbfd42` (2,847,754 bytes) |

## UN Comtrade

Imports of crude oil (HS 2709, "Petroleum oils and oils obtained from bituminous minerals; crude"), annual, by partner country, for each of the eight main suppliers of refined fuel to Australia. `R/download_comtrade.R` downloads each file from the UN Comtrade public API and saves it unchanged in `comtrade/`. The files are not stored in this repository.

- Publisher: United Nations Statistics Division, UN Comtrade Database, https://comtradeplus.un.org/
- Volume used: `netWgt`, net weight in kilograms, for each partner (`partnerCode` not 0). The row with `partnerCode` 0 is the World total and is not used.
- Taiwan reports to UN Comtrade as "Other Asia, nes" (reporter code 490). Its latest annual data are for 2024.
- Terms of use: see the UN Comtrade website.

| File | Reporter (code) | Year |
|---|---|---|
| `comtrade_2709_imports_singapore_2025.json` | Singapore (702) | 2025 |
| `comtrade_2709_imports_south_korea_2025.json` | Rep. of Korea (410) | 2025 |
| `comtrade_2709_imports_malaysia_2025.json` | Malaysia (458) | 2025 |
| `comtrade_2709_imports_taiwan_2024.json` | Other Asia, nes (490) | 2024 |
| `comtrade_2709_imports_india_2025.json` | India (699) | 2025 |
| `comtrade_2709_imports_china_2025.json` | China (156) | 2025 |
| `comtrade_2709_imports_brunei_2025.json` | Brunei Darussalam (96) | 2025 |
| `comtrade_2709_imports_japan_2025.json` | Japan (392) | 2025 |

Each file comes from this address, with the reporter code and year from the table:

```
https://comtradeapi.un.org/public/v1/preview/C/A/HS?reporterCode=702&period=2025&cmdCode=2709&flowCode=M&includeDesc=true
```

The figures in this repository use files downloaded on 9 November 2026. UN Comtrade revises its data, so a later download can differ.
