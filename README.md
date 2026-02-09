# SmartRemindera — проект

Кратко: этот репозиторий содержит iOS-приложение SmartRemindera (SwiftUI, MVVM). Ниже — быстрый чек-лист для сдачи и инструкции.

Local checklist
- [x] TabView, NavigationStack, List, CRUD (file-based JSON repository)
- [x] MVVM: ViewModels в `Presentation/ViewModels`
- [x] Persistence: `Infrastructure/Persistence/ReminderRepository.swift` (JSON + UserDefaults migration)
- [x] CI: GitHub Actions workflow (`.github/workflows/ci.yml`) выполняет сборку и тесты на macOS
- [ ] Network: добавить настоящий API (есть stub `Infrastructure/Network/APIClient.swift`)

How to run (on macOS / Xcode)

1. Откройте `SmartRemindera/SmartRemindera.xcodeproj` в Xcode.
2. Выберите схему `SmartRemindera`, цель iOS Simulator (например, iPhone 15).
3. Build & Run или нажмите ⌘R.

Tests

В GitHub Actions настроен job для запуска `xcodebuild test`. Локально запуск:

```bash
# на macOS с Xcode установленным
xcodebuild -scheme SmartRemindera -project SmartRemindera/SmartRemindera.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 15' test
```

Что я добавил здесь
- `docs/requirements_mapping.md` — матрица соответствия требований к коду.
- `SmartRemindera/SmartRemindera/Infrastructure/Network/APIClient.swift` — `URLSession` stub для интеграции REST API.
- `docs/network.md` — примеры cURL, Postman и инструкция по интеграции.
- `docs/diagrams/*` — mermaid-диаграммы (ERD / Use Case).
- `docs/report_draft.md` — начальный черновик отчёта (в `docs/`).
# Smart Reminders iOS Application

A complete iOS application showcasing native iOS capabilities with clean architecture.

## Features

### ✨ Smart Reminders
- **Time-based reminders** with precise scheduling
- **Location-based reminders** using geofencing (enter/exit)
- **Adaptive behavior** driven by rules engine
- **Snooze, Complete, Ignore** tracking with pattern analysis
- **Explainability** showing why reminders are rescheduled or escalated

### 📱 Live Activity
- Dynamic Island integration (iOS 16.1+)
- Lock screen presentation
- Real-time countdown timer
- Interactive buttons (Done, Snooze) via AppIntents
- Escalation level indicators

### 📍 Geolocation
- CoreLocation integration
- Geofencing support (enter/exit/both)
- Location picker for reminders
- Automatic reminder activation on location triggers

### 🔔 Smart Notifications
- Escalation-based notification levels
- Critical alerts for high-priority reminders
- Notification actions (Complete, Snooze)
- Automatic rescheduling based on rules

### 📊 Statistics
- Completion rate tracking
- Snooze pattern analysis
- Productivity insights (most productive hours)
- Behavior pattern visualization

## Architecture

### Clean Architecture Layers

```
SmartRemindersCore (Swift Package)
├── Domain
│   ├── Entities (Reminder, ReminderHistory, ReminderDecision)
│   ├── Rules (ReminderRule, ReminderRulesEngine)
│   ├── UseCases (Create, Snooze, Complete, Evaluate)
│   └── Services (Protocols)

SmartRemindera (iOS App)
├── Infrastructure
│   ├── Services (NotificationServiceImpl, LocationServiceImpl, LiveActivityServiceImpl)
│   └── Persistence (ReminderRepository)
├── Application
│   ├── DependencyContainer
│   └── ReminderCoordinator
├── Presentation
│   ├── ViewModels (MVVM pattern)
│   └── Views (SwiftUI)
└── LiveActivity
    ├── ReminderActivityAttributes
    ├── ReminderLiveActivity
    └── ReminderAppIntents
```

### Design Patterns
- **MVVM** for presentation layer
- **Use Cases** for business logic
- **Dependency Injection** via initializers
- **Repository Pattern** for data persistence
- **Coordinator Pattern** for app-wide state management

## Setup Instructions

### Prerequisites
- Xcode 15.0+
- iOS 16.0+ (iOS 16.1+ for Live Activities)
- macOS Ventura or later

### Installation

1. **Add SmartRemindersCore Package to Xcode**
   - Open `SmartRemindera.xcodeproj` in Xcode
   - Go to File → Add Package Dependencies
   - Click "Add Local..."
   - Navigate to `SmartRemindersCore` folder and select it
   - Add the package to the SmartRemindera target

2. **Configure Signing**
   - Select the SmartRemindera target
   - Go to Signing & Capabilities
   - Select your development team
   - Ensure "Automatically manage signing" is checked

3. **Add Required Capabilities**
   - In Signing & Capabilities, click "+ Capability"
   - Add:
     - **Push Notifications** (for Live Activities)
     - **Background Modes** → Enable "Location updates"

4. **Build and Run**
   - Select a simulator or device (iOS 16.0+)
   - Press Cmd+R to build and run

### Testing Live Activities

Live Activities require a physical device with iOS 16.1+ or the iOS Simulator with iOS 16.2+.

To test:
1. Create a reminder with a near-future time (e.g., 2 minutes from now)
2. Tap "Activate" on the reminder
3. The Live Activity will appear in the Dynamic Island and lock screen
4. Test the "Done" and "Snooze" buttons

### Testing Location Triggers

Location-based reminders require a physical device or simulator location simulation:

1. Create a reminder with location trigger
2. Tap "Use Current Location" or enter coordinates manually
3. On simulator: Debug → Location → Custom Location
4. Move to/from the geofence area
5. The reminder will activate automatically

## Project Structure

```
SmartReminders/
├── SmartRemindersCore/              # Swift Package
│   ├── Package.swift
│   ├── Sources/SmartRemindersCore/
│   │   └── Domain/
│   │       ├── Entities/
│   │       ├── Rules/
│   │       ├── UseCases/
│   │       └── Services/
│   └── Tests/
│
└── SmartRemindera/                  # iOS App
    ├── SmartRemindera/
    │   ├── SmartReminderaApp.swift
    │   ├── ContentView.swift
    │   ├── Info.plist
    │   ├── Infrastructure/
    │   │   ├── Services/
    │   │   └── Persistence/
    │   ├── Application/
    │   │   ├── DependencyContainer.swift
    │   │   └── ReminderCoordinator.swift
    │   ├── Presentation/
    │   │   ├── ViewModels/
    │   │   └── Views/
    │   └── LiveActivity/
    │       ├── ReminderActivityAttributes.swift
    │       ├── ReminderLiveActivity.swift
    │       └── ReminderAppIntents.swift
    └── SmartRemindera.xcodeproj
```

## Usage

### Creating a Reminder

1. Tap the "+" button in the Reminders tab
2. Enter a title and optional notes
3. Choose priority level
4. Enable time-based or location-based trigger (or both)
5. For time triggers: select date and time
6. For location triggers: tap "Use Current Location" or enter coordinates
7. Tap "Save"

### Viewing Explainability

1. Tap on any reminder in the list
2. Scroll to the "Why This Behavior?" section
3. View the rules engine's explanation for adaptive behavior
4. See recommended next trigger times and escalation reasons

### Monitoring Statistics

1. Navigate to the "Stats" tab
2. View completion rate, snooze patterns, and productivity insights
3. Tap "Refresh Stats" to update metrics

## Rules Engine Behavior

The app includes an intelligent rules engine that adapts to user behavior:

### Snooze Pattern Detection
- Tracks snooze frequency
- Increases snooze duration for frequently snoozed reminders
- Escalates priority after multiple snoozes

### Time Optimization
- Learns when you typically complete reminders
- Suggests optimal scheduling times
- Adapts to your productivity patterns

### Escalation Logic
- Increases notification urgency for ignored reminders
- Uses critical alerts for high-priority items
- Provides clear explanations for escalations

### Location Suggestions
- Recommends location triggers for frequently snoozed reminders
- Helps make reminders more contextual

## Technical Highlights

- **Actor-based concurrency** for thread-safe repository
- **Async/await** throughout the codebase
- **Combine** for reactive state management
- **SwiftUI** for declarative UI
- **ActivityKit** for Live Activities
- **CoreLocation** for geofencing
- **UserNotifications** with custom categories
- **AppIntents** for Live Activity interactions

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## License

This is a demonstration project for educational purposes.

## Author

Created as a complete iOS application showcasing clean architecture and native iOS capabilities.
