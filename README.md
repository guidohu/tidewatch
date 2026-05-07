# Tide Watch

Tide Watch is a powerful and customizable Garmin watch face designed for surfers and coastal enthusiasts. It provides real-time tide and swell data directly on your wrist, helping you stay informed about the latest conditions at your favorite surf spots.

![Tide Watch Screenshot](img/Screenshot%202026-04-03%20at%2012.54.18.png)

If you like this watch face, please consider supporting its development:

[![Sponsor this Work](https://img.shields.io/badge/Sponsor_this_Work-guidohu-orange?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/guidohu)

## Key Features

- **Tide & Swell Graphs**: High-resolution graphs that visualize tide and optional swell height trends over time.
- **Stormglass.io Integration**: Get detailed swell information by providing your own Stormglass.io API key.
- **Global Tide Data**: Uses your GPS coordinates to automatically fetch the most relevant tide data for your location.
- **Customizable Units**: Toggle between Metric (Meters) and Imperial (Feet) for tide and swell heights independently.
- **Rich Personalization**:
  - Choose from an expanded palette of colors for tide height, the tide graph, and base text (including Petrol, Turquoise, and more).
  - Optional swell graph layering to see swell trends alongside tide.
  - Toggle date and day display for a cleaner look.
- **Smart Background Updates**: Efficient data fetching to minimize battery impact while keeping indicators up-to-date.
- **Status Indicators at a Glance**:
  - **Yellow**: Indicates stale data (older than 12 hours) or a recent sync error.
  - **Red**: Indicates an active synchronization error or very low battery.

## Configuration

To set up Tide Watch:
1.  **Location**:
    - **GPS Coordinates**: In the Garmin Connect IQ app settings, enter your **Latitude** and **Longitude** (e.g., `21.27` and `-157.82` for Waikiki). This is required to fetch local tide data.
2.  **Swell Data (Optional)**:
    - **Stormglass.io API Key**: If you want to see swell graphs and summaries, you must provide an API key from [stormglass.io](https://stormglass.io). Enter this key in the **Stormglass API Key** field.
3.  **Units & Appearance**:
    - Select your preferred units (Meters or Feet).
    - Personalize the colors for the tide graph, text, and indicators.


## Supported Devices

Tide Watch supports most modern Garmin wearables, including:

- **Fenix** (5 Plus, 6, 7, 8, E and all Solar editions)
- **Forerunner** (55, 165, 245, 255, 265, 570, 745, 945, 955, 965, 970)
- **Venu** (Original, 2, 3, 4, Sq, Sq 2, Venu Air)
- **Instinct** (2, 2s, 2x, 3, Crossover, E)
- **Descent** (G1, G2, Mk2, Mk3)
- **Epix** (Gen 2, Pro editions)
- **Enduro** (Original, 3)
- **MARQ** (Original and Gen 2)
- **Vivoactive** (3m, 4, 5, 6)
- **Approach** (S50, S70)
- **D2** (Air, Mach 1, Mach 2)

## License

**Copyright (c) 2026 Tide Watch Developers**

This software (the "App") is free to use for personal purposes. However, you are **strictly prohibited** from forking, modifying, editing, or redistributing the source code or any derivative works of this App.

The software is provided "as is", without warranty of any kind.

