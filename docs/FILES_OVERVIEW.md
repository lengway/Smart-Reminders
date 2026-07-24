# SmartReminders — что делает каждый файл

Дата: 2026-02-10

Ниже — краткое назначение **каждого файла**, который сейчас входит в проект. Описания основаны на структуре и имени файла, а для ключевых компонентов — на прочитанном коде.

---

## Корень проекта

- [.gitignore](../.gitignore) — правила игнорирования файлов для Git.
- [README.md](../README.md) — краткое описание проекта.

### GitHub Actions

- [.github/workflows/ci.yml](../.github/workflows/ci.yml) — CI-пайплайн.

---

## Документация

- [docs/ARCHITECTURE.md](ARCHITECTURE.md) — полная архитектура, обоснования и детали.
- [docs/network.md](network.md) — заметки по сетевому взаимодействию.
- [docs/report_draft.md](report_draft.md) — черновик отчёта.
- [docs/requirements_mapping.md](requirements_mapping.md) — сопоставление требований и реализации.
- [docs/PROJECT_GUIDE.md](PROJECT_GUIDE.md) — полный гид по проекту.
- [docs/ReminderRulesEngine.md](ReminderRulesEngine.md) — подробности про движок правил.
- [docs/FINAL PROJECT REQUIREMENTS.docx](FINAL%20PROJECT%20REQUIREMENTS.docx) — требования в формате docx.

### Диаграммы

- [docs/diagrams/usecase.mmd](diagrams/usecase.mmd) — диаграмма сценариев использования (Mermaid).
- [docs/diagrams/reminder_er.mmd](diagrams/reminder_er.mmd) — ER-диаграмма (Mermaid).

---

## Приложение (SmartRemindera)

### Корневые файлы приложения

- [SmartRemindera/SmartRemindera/SmartReminderaApp.swift](../SmartRemindera/SmartRemindera/SmartReminderaApp.swift) — точка входа приложения (SwiftUI App).
- [SmartRemindera/SmartRemindera/ContentView.swift](../SmartRemindera/SmartRemindera/ContentView.swift) — корневой SwiftUI View.
- [SmartRemindera/SmartRemindera/PrivacyManifest.json](../SmartRemindera/SmartRemindera/PrivacyManifest.json) — манифест приватности iOS.
- [SmartRemindera/SmartRemindera/.swiftlint.yml](../SmartRemindera/SmartRemindera/.swiftlint.yml) — конфиг SwiftLint.

### Application Layer

- [SmartRemindera/SmartRemindera/Application/DependencyContainer.swift](../SmartRemindera/SmartRemindera/Application/DependencyContainer.swift) — DI-контейнер, создаёт все зависимости.
- [SmartRemindera/SmartRemindera/Application/ReminderCoordinator.swift](../SmartRemindera/SmartRemindera/Application/ReminderCoordinator.swift) — координатор жизненного цикла напоминаний.
- [SmartRemindera/SmartRemindera/Application/BackgroundTaskManager.swift](../SmartRemindera/SmartRemindera/Application/BackgroundTaskManager.swift) — фоновые задачи и обновление уведомлений.
- [SmartRemindera/SmartRemindera/Application/Telemetry.swift](../SmartRemindera/SmartRemindera/Application/Telemetry.swift) — логирование событий.

### Infrastructure Layer

#### Network

- [SmartRemindera/SmartRemindera/Infrastructure/Network/APIClient.swift](../SmartRemindera/SmartRemindera/Infrastructure/Network/APIClient.swift) — HTTP-клиент для синхронизации напоминаний.

#### Persistence

- [SmartRemindera/SmartRemindera/Infrastructure/Persistence/ReminderRepository.swift](../SmartRemindera/SmartRemindera/Infrastructure/Persistence/ReminderRepository.swift) — файловое хранилище напоминаний и истории.

#### Services

- [SmartRemindera/SmartRemindera/Infrastructure/Services/NotificationServiceImpl.swift](../SmartRemindera/SmartRemindera/Infrastructure/Services/NotificationServiceImpl.swift) — работа с UNUserNotificationCenter.
- [SmartRemindera/SmartRemindera/Infrastructure/Services/LocationServiceImpl.swift](../SmartRemindera/SmartRemindera/Infrastructure/Services/LocationServiceImpl.swift) — геолокация/геозоны CoreLocation.
- [SmartRemindera/SmartRemindera/Infrastructure/Services/LiveActivityServiceImpl.swift](../SmartRemindera/SmartRemindera/Infrastructure/Services/LiveActivityServiceImpl.swift) — Live Activities (ActivityKit).

### Presentation Layer

#### ViewModels

- [SmartRemindera/SmartRemindera/Presentation/ViewModels/ReminderListViewModel.swift](../SmartRemindera/SmartRemindera/Presentation/ViewModels/ReminderListViewModel.swift) — логика списка напоминаний.
- [SmartRemindera/SmartRemindera/Presentation/ViewModels/CreateReminderViewModel.swift](../SmartRemindera/SmartRemindera/Presentation/ViewModels/CreateReminderViewModel.swift) — логика формы создания.
- [SmartRemindera/SmartRemindera/Presentation/ViewModels/ActiveReminderViewModel.swift](../SmartRemindera/SmartRemindera/Presentation/ViewModels/ActiveReminderViewModel.swift) — логика активного напоминания.
- [SmartRemindera/SmartRemindera/Presentation/ViewModels/ReminderDetailViewModel.swift](../SmartRemindera/SmartRemindera/Presentation/ViewModels/ReminderDetailViewModel.swift) — логика экрана детали.
- [SmartRemindera/SmartRemindera/Presentation/ViewModels/PermissionsViewModel.swift](../SmartRemindera/SmartRemindera/Presentation/ViewModels/PermissionsViewModel.swift) — управление разрешениями.
- [SmartRemindera/SmartRemindera/Presentation/ViewModels/StatsViewModel.swift](../SmartRemindera/SmartRemindera/Presentation/ViewModels/StatsViewModel.swift) — данные для статистики.

#### Views

- [SmartRemindera/SmartRemindera/Presentation/Views/ReminderListView.swift](../SmartRemindera/SmartRemindera/Presentation/Views/ReminderListView.swift) — экран списка.
- [SmartRemindera/SmartRemindera/Presentation/Views/CreateReminderView.swift](../SmartRemindera/SmartRemindera/Presentation/Views/CreateReminderView.swift) — экран создания.
- [SmartRemindera/SmartRemindera/Presentation/Views/ActiveReminderView.swift](../SmartRemindera/SmartRemindera/Presentation/Views/ActiveReminderView.swift) — экран активного напоминания.
- [SmartRemindera/SmartRemindera/Presentation/Views/ReminderDetailView.swift](../SmartRemindera/SmartRemindera/Presentation/Views/ReminderDetailView.swift) — экран деталей напоминания.
- [SmartRemindera/SmartRemindera/Presentation/Views/OnboardingView.swift](../SmartRemindera/SmartRemindera/Presentation/Views/OnboardingView.swift) — onboarding-экран.
- [SmartRemindera/SmartRemindera/Presentation/Views/PermissionsBannerView.swift](../SmartRemindera/SmartRemindera/Presentation/Views/PermissionsBannerView.swift) — баннер разрешений.
- [SmartRemindera/SmartRemindera/Presentation/Views/StatsView.swift](../SmartRemindera/SmartRemindera/Presentation/Views/StatsView.swift) — экран статистики.
- [SmartRemindera/SmartRemindera/Presentation/Views/Components/](../SmartRemindera/SmartRemindera/Presentation/Views/Components/) — папка для UI-компонентов (пока без файлов).

### Live Activity (App)

- [SmartRemindera/SmartRemindera/LiveActivity/ReminderActivityAttributes.swift](../SmartRemindera/SmartRemindera/LiveActivity/ReminderActivityAttributes.swift) — ActivityKit атрибуты для Live Activity внутри приложения.

### Локализация

- [SmartRemindera/SmartRemindera/Resources/Base.lproj/Localizable.strings](../SmartRemindera/SmartRemindera/Resources/Base.lproj/Localizable.strings) — базовые строки локализации.
- [SmartRemindera/SmartRemindera/Resources/ru.lproj/Localizable.strings](../SmartRemindera/SmartRemindera/Resources/ru.lproj/Localizable.strings) — русская локализация.

### Assets (App)

- [SmartRemindera/SmartRemindera/Assets.xcassets/Contents.json](../SmartRemindera/SmartRemindera/Assets.xcassets/Contents.json) — индекс каталога ассетов.
- [SmartRemindera/SmartRemindera/Assets.xcassets/AccentColor.colorset/Contents.json](../SmartRemindera/SmartRemindera/Assets.xcassets/AccentColor.colorset/Contents.json) — описание accent color.
- [SmartRemindera/SmartRemindera/Assets.xcassets/AppIcon.appiconset/Contents.json](../SmartRemindera/SmartRemindera/Assets.xcassets/AppIcon.appiconset/Contents.json) — описание иконок приложения.

---

## Widgets и Extensions (SmartReminderaWidgets)

- [SmartRemindera/SmartReminderaWidgets/SmartReminderaWidgetsBundle.swift](../SmartRemindera/SmartReminderaWidgets/SmartReminderaWidgetsBundle.swift) — точка входа для набора виджетов.
- [SmartRemindera/SmartReminderaWidgets/SmartReminderaWidgets.swift](../SmartRemindera/SmartReminderaWidgets/SmartReminderaWidgets.swift) — основная конфигурация виджета.
- [SmartRemindera/SmartReminderaWidgets/SmartReminderaWidgetsControl.swift](../SmartRemindera/SmartReminderaWidgets/SmartReminderaWidgetsControl.swift) — управление виджетом.
- [SmartRemindera/SmartReminderaWidgets/SmartReminderaWidgetsLiveActivity.swift](../SmartRemindera/SmartReminderaWidgets/SmartReminderaWidgetsLiveActivity.swift) — конфигурация Live Activity в виджет-экстеншене.
- [SmartRemindera/SmartReminderaWidgets/ReminderLiveActivity.swift](../SmartRemindera/SmartReminderaWidgets/ReminderLiveActivity.swift) — UI Live Activity (Dynamic Island).
- [SmartRemindera/SmartReminderaWidgets/ReminderActivityAttributes.swift](../SmartRemindera/SmartReminderaWidgets/ReminderActivityAttributes.swift) — ActivityKit атрибуты для виджета.
- [SmartRemindera/SmartReminderaWidgets/ReminderAppIntents.swift](../SmartRemindera/SmartReminderaWidgets/ReminderAppIntents.swift) — App Intents для Siri/Shortcuts.
- [SmartRemindera/SmartReminderaWidgets/ReminderShortcuts.swift](../SmartRemindera/SmartReminderaWidgets/ReminderShortcuts.swift) — Siri Shortcuts.
- [SmartRemindera/SmartReminderaWidgets/AppIntent.swift](../SmartRemindera/SmartReminderaWidgets/AppIntent.swift) — базовые Intent-конфигурации.
- [SmartRemindera/SmartReminderaWidgets/Info.plist](../SmartRemindera/SmartReminderaWidgets/Info.plist) — конфигурация расширения.

### Assets (Widgets)

- [SmartRemindera/SmartReminderaWidgets/Assets.xcassets/Contents.json](../SmartRemindera/SmartReminderaWidgets/Assets.xcassets/Contents.json) — индекс ассетов виджета.
- [SmartRemindera/SmartReminderaWidgets/Assets.xcassets/AccentColor.colorset/Contents.json](../SmartRemindera/SmartReminderaWidgets/Assets.xcassets/AccentColor.colorset/Contents.json) — accent color виджета.
- [SmartRemindera/SmartReminderaWidgets/Assets.xcassets/AppIcon.appiconset/Contents.json](../SmartRemindera/SmartReminderaWidgets/Assets.xcassets/AppIcon.appiconset/Contents.json) — иконки виджета.
- [SmartRemindera/SmartReminderaWidgets/Assets.xcassets/WidgetBackground.colorset/Contents.json](../SmartRemindera/SmartReminderaWidgets/Assets.xcassets/WidgetBackground.colorset/Contents.json) — фон виджета.

---

## Core-модуль (SmartRemindersCore)

- [SmartRemindersCore/Package.swift](../SmartRemindersCore/Package.swift) — Swift Package модуля Core.

### Domain / Entities

- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/Entities/Reminder.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/Entities/Reminder.swift) — основная модель напоминания.
- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/Entities/ReminderHistory.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/Entities/ReminderHistory.swift) — история взаимодействий.
- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/Entities/ReminderDecision.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/Entities/ReminderDecision.swift) — результат решения движка.

### Domain / Rules

- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/Rules/ReminderRule.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/Rules/ReminderRule.swift) — протокол правил.
- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/Rules/ReminderRulesEngine.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/Rules/ReminderRulesEngine.swift) — движок правил.

### Domain / Services (протоколы)

- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/Services/NotificationService.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/Services/NotificationService.swift) — контракт уведомлений.
- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/Services/LocationService.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/Services/LocationService.swift) — контракт геолокации.
- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/Services/LiveActivityService.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/Services/LiveActivityService.swift) — контракт Live Activity.
- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/Services/PersonalizationService.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/Services/PersonalizationService.swift) — контракт персонализации.

### Domain / UseCases

- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/UseCases/CreateReminderUseCase.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/UseCases/CreateReminderUseCase.swift) — создание напоминания.
- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/UseCases/SnoozeReminderUseCase.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/UseCases/SnoozeReminderUseCase.swift) — snooze с правилами.
- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/UseCases/CompleteReminderUseCase.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/UseCases/CompleteReminderUseCase.swift) — завершение напоминания.
- [SmartRemindersCore/Sources/SmartRemindersCore/Domain/UseCases/EvaluateReminderUseCase.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/UseCases/EvaluateReminderUseCase.swift) — оценка напоминания без изменения.

### Tests (Core)

- [SmartRemindersCore/Tests/SmartRemindersCoreTests/ReminderRulesEngineTests.swift](../SmartRemindersCore/Tests/SmartRemindersCoreTests/ReminderRulesEngineTests.swift) — тесты движка правил.

---

## Тесты приложения

- [SmartRemindera/SmartReminderaTests/SmartReminderaTests.swift](../SmartRemindera/SmartReminderaTests/SmartReminderaTests.swift) — unit-тесты приложения.
- [SmartRemindera/SmartReminderaUITests/SmartReminderaUITests.swift](../SmartRemindera/SmartReminderaUITests/SmartReminderaUITests.swift) — UI-тесты.
- [SmartRemindera/SmartReminderaUITests/SmartReminderaUITestsLaunchTests.swift](../SmartRemindera/SmartReminderaUITests/SmartReminderaUITestsLaunchTests.swift) — тесты запуска UI.

---

## Xcode-проект

- [SmartRemindera/SmartRemindera.xcodeproj/project.pbxproj](../SmartRemindera/SmartRemindera.xcodeproj/project.pbxproj) — конфигурация Xcode-проекта.
- [SmartRemindera/SmartRemindera.xcodeproj/project.xcworkspace/contents.xcworkspacedata](../SmartRemindera/SmartRemindera.xcodeproj/project.xcworkspace/contents.xcworkspacedata) — состав workspace.
- [SmartRemindera/SmartRemindera.xcodeproj/xcuserdata/lejlazunisbekova.xcuserdatad/xcschemes/xcschememanagement.plist](../SmartRemindera/SmartRemindera.xcodeproj/xcuserdata/lejlazunisbekova.xcuserdatad/xcschemes/xcschememanagement.plist) — пользовательские схемы.

---

## Примечание

Папки .git/ и SmartRemindersCore/.build/ содержат служебные и build-артефакты, их список в этом документе не приводится.
