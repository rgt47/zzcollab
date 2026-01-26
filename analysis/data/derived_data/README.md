# Processed Data: Palmer Penguins (Clean)

## Source
Processed from `analysis/data/raw_data/penguins_raw.csv`

## Processing Steps
See: `analysis/scripts/01_process_data.R`

1. Loaded raw data
2. Removed rows with missing bill measurements
3. Added derived variables:
   - bill_ratio: bill_length_mm / bill_depth_mm
   - size_category: small (<3500g), medium (3500-4500g), large (>4500g)

## Quality Checks
- All rows have complete bill measurements
- All derived variables computed successfully
- No outliers detected beyond expected range
