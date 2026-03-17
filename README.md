# FitLife

A personal fitness tracking iOS app built with SwiftUI.

## Features

- **Home** — Daily overview, mood tracking, weight log, and calendar view
- **Diet** — Food logging with AI-powered food recognition via camera
- **Training** — Workout tracking for strength and cardio exercises
- **Report** — Progress charts and health data visualization
- **Profile** — Body info management and HealthKit integration

## Tech Stack

- SwiftUI
- HealthKit
- Google Gemini AI (food recognition)
- XcodeGen (`project.yml`)

## Project Structure

```
FitLife/
├── FitLife/
│   ├── App/              # Entry point
│   ├── Views/            # UI screens (Home, Diet, Training, Report, Profile)
│   ├── Models/           # Data models
│   ├── Services/         # AI, HealthKit, data persistence
│   └── Assets.xcassets/  # Images and app icon
├── FitLife.xcodeproj
└── project.yml
```

## Requirements

- Xcode 15+
- iOS 17+
- Physical device recommended (HealthKit requires real hardware)

## Getting Started

1. Clone the repo
2. Open `FitLife.xcodeproj` in Xcode
3. Set your own signing team in project settings
4. Build and run on your device
