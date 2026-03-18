## DJI M300 + MicaSense Altum Coverage Calculator

### Overview
This repository provides an Excel and Shiny-based tool for estimating UAV mapping performance using the DJI Matrice 300 RTK and MicaSense Altum sensor.

### Features
- Coverage estimation (ha, km2, acre/hr)
- Image acquisition metrics (time between captures, number of captures, total images)
- Storage estimation (GB)
- Flight geometry (footprint, spacing)
- Adjustable mission parameters (altitude, speed, overlap, flight time, bands)

### Repository Contents
- DJIM300-Altum-calculator.xlsx
- DJIM300-Altum-calculator.R
- README.md

### Key Calculations
- Footprint derived from altitude and sensor FOV
- Along-track spacing = footprint height × (1 - forward overlap)
- Cross-track spacing = footprint width × (1 - side overlap)
- Time between captures = spacing / speed
- Area = swath width × path length
- Images = captures × bands
- Storage = captures × file size

### Excel Usage
1. Open the Excel file
2. Modify input cells
3. Outputs update automatically

### Shiny Usage
Install and run in R:
```
install.packages("shiny")
shiny::runApp("DJIM300-Altum-calculator.R")
```
### Use Cases
- Ecological UAV surveys
- Floodplain and riparian mapping
- Agricultural monitoring
- Flight planning
- Storage estimation

### Notes
- Assumes constant speed and altitude
- Does not include terrain, wind, or turning time
- Storage estimates depend on file format and compression

### Author
Jacob Nesslage

PhD Candidate, UC Merced

### License
MIT
