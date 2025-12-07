# Changelog

All notable changes to Frictionless will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **CPU Detail Chart**: Beautiful stacked area chart showing System (red) and User (blue) CPU usage over time
  - OLED black background for perfect contrast
  - Live legend with color-coded percentages for System, User, and Idle
- **Network Activity Chart**: Stacked area chart displaying network traffic
  - Purple for download activity
  - Orange for upload activity
  - Real-time speed indicators with color-coded values
  - Session totals for in/out traffic

### Changed
- **Disk View Redesign**: 
  - Free space now prominently displayed as primary metric
  - Dynamic color thresholds:
    - Green: >25% free (healthy)
    - Yellow: 10.1-25% free (warning)
    - Red: ≤10% free (critical)
  - Removed "Clean Up" feature for cleaner interface
  - Simplified info display: "X GB free" / "Y GB used / Z GB total"
- **Memory Calculation**: Updated formula to better match system reporting (Total - Available)
- **CPU Monitoring**: Enhanced breakdown with precise System/User/Idle percentages
- **UI Consistency**: All detail windows now share consistent 240x240 dimensions and OLED black styling

### Improved
- Chart rendering performance and accuracy across all resource monitors
- Legend layouts with better spacing and readability
- Color coordination across all visualizations

### Fixed
- CPU chart now correctly displays both System and User components in stacked format
- Memory calculation race conditions eliminated
- Network IP detection now filters out link-local addresses (169.254.x.x)
- Disk usage reporting now accounts for purgeable space

## [Previous Versions]
(Add previous version history here as needed)
