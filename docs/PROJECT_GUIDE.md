# SmartReminders — Пофункциональное руководство по всему проекту

Дата: 2026-02-10

Этот документ содержит полное описание всех компонентов проекта SmartReminders: что делает каждый класс, почему именно так реализовано, и как это работает вместе.

---

## Оглавление

1. [Общая архитектура](#общая-архитектура)
2. [Application Layer](#application-layer)
3. [Infrastructure Layer](#infrastructure-layer)
4. [Domain Layer (SmartRemindersCore)](#domain-layer-smartreminderscore)
5. [Presentation Layer](#presentation-layer)
6. [Widgets и Extensions](#widgets-и-extensions)
7. [Как всё работает вместе](#как-всё-работает-вместе)

---

## Общая архитектура

SmartReminders построен на **Clean Architecture** с чёткими слоями:

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│   (Views, ViewModels, UI Logic)        │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Application Layer               │
│   (Coordinator, DI, Background Tasks)   │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Domain Layer (Core)             │
│   (Entities, UseCases, Rules Engine)    │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Infrastructure Layer            │
│   (Network, Persistence, Services)      │
└─────────────────────────────────────────┘
```

**Принцип:** внутренние слои (Domain) не знают о внешних (UI, Infrastructure). Зависимости направлены внутрь.

---

## Application Layer

Отвечает за координацию, dependency injection и фоновые задачи.

### DependencyContainer

**Расположение:** [SmartRemindera/Application/DependencyContainer.swift](../SmartRemindera/SmartRemindera/Application/DependencyContainer.swift)

**Назначение:** централизованный контейнер для создания и управления всеми зависимостями приложения.

#### `init()`

**Что делает:** создаёт все необходимые сервисы, use cases и координатор.

**Почему так:** паттерн Dependency Injection. Все зависимости создаются в одном месте, что упрощает тестирование и замену реализаций.

**Как работает:**
1. Инициализирует сервисы (`NotificationServiceImpl`, `LocationServiceImpl`, `LiveActivityServiceImpl`)
2. Создаёт `ReminderRepository` для работы с данными
3. Инициализирует `ReminderRulesEngine` с дефолтными правилами
4. Создаёт use cases, передавая им сервисы
5. Инициализирует `ReminderCoordinator`, который управляет всей бизнес-логикой
6. Поддерживает iOS 16.2+ для Live Activities, на старых версиях использует NoOp-заглушку

**Связь с другими компонентами:** это корневой объект, который живёт на протяжении всей жизни приложения и предоставляет все необходимые зависимости.

---

### ReminderCoordinator

**Расположение:** [SmartRemindera/Application/ReminderCoordinator.swift](../SmartRemindera/SmartRemindera/Application/ReminderCoordinator.swift)

**Назначение:** центральный диспетчер жизненного цикла напоминаний.

#### Основные функции

##### `createReminder(...)`

**Что делает:** создаёт новое напоминание с временными или геолокационными триггерами.

**Почему так:** вся логика создания инкапсулирована в `CreateReminderUseCase`, coordinator просто вызывает его и сохраняет результат.

**Как работает:**
1. Вызывает `createUseCase.execute()` с параметрами
2. Сохраняет напоминание через `repository.saveReminder()`
3. Перезагружает список напоминаний
4. Логирует событие через `telemetry`

##### `snoozeReminder(id:)`

**Что делает:** откладывает напоминание, применяя правила движка.

**Почему так:** snooze — это не просто сдвиг времени. Система анализирует историю и может:
- Увеличить длительность snooze при частом откладывании
- Повысить эскалацию
- Предложить изменение триггера

**Как работает:**
1. Загружает напоминание и историю
2. Вызывает `snoozeUseCase.execute()`, который применяет правила
3. Сохраняет обновлённое напоминание и историю
4. Обновляет Live Activity, если напоминание активно
5. Логирует с уровнем эскалации

##### `completeReminder(id:)`

**Что делает:** завершает напоминание, отменяет уведомления и геозоны.

**Как работает:**
1. Получает напоминание
2. Вызывает `completeUseCase.execute()`, который:
   - Отменяет notification
   - Останавливает monitoring геолокации
   - Завершает Live Activity
3. Сохраняет обновлённую историю (увеличивает completion count)

##### `activateReminder(id:)`

**Что делает:** переводит напоминание в активное состояние (отображается в Dynamic Island).

**Почему так:** только одно напоминание может быть активным. Live Activities имеют лимиты.

**Как работает:**
1. Деактивирует текущее активное напоминание
2. Переводит выбранное в статус `.active`
3. Запускает Live Activity

##### `deleteReminder(id:)`

**Что делает:** полностью удаляет напоминание.

**Как работает:**
1. Получает напоминание
2. Отменяет все триггеры (notification, geofence, live activity)
3. Удаляет из repository

#### Дополнительные методы

- `loadReminders()` — загружает список из БД и обновляет `@Published var reminders`
- `setupLocationTriggerCallback()` — подписывается на геолокационные события
- `evaluateAllReminders()` — прогоняет все напоминания через rules engine (фоновая задача)

**Связь с другими компонентами:** единственная точка входа для всех операций с напоминаниями. ViewModel'ы вызывают методы координатора, а не работают с repository напрямую.

---

### BackgroundTaskManager

**Расположение:** [SmartRemindera/Application/BackgroundTaskManager.swift](../SmartRemindera/SmartRemindera/Application/BackgroundTaskManager.swift)

**Назначение:** управляет фоновым обновлением уведомлений через BGTaskScheduler.

#### `configure(coordinator:notificationService:)`

**Что делает:** регистрирует фоновую задачу и планирует первый запуск.

**Почему так:** iOS требует регистрации background tasks в `Info.plist` и `BGTaskScheduler`.

**Как работает:**
1. Регистрирует task identifier `com.smartreminders.refresh`
2. Планирует запуск через 30 минут

#### `handleRefresh(task:)`

**Что делает:** выполняет обновление уведомлений в фоне.

**Как работает:**
1. Перепланирует следующий запуск
2. Получает все запланированные напоминания
3. Обновляет их уведомления (на случай изменения trigger'ов)
4. Уведомляет систему о завершении

**Связь с другими компонентами:** запускается системой iOS, независимо от запущенного приложения.

---

### Telemetry

**Расположение:** [SmartRemindera/Application/Telemetry.swift](../SmartRemindera/SmartRemindera/Application/Telemetry.swift)

**Назначение:** централизованное логирование событий.

#### `log(event:properties:)`

**Что делает:** записывает событие в os.log.

**Почему так:** в будущем можно заменить на Firebase Analytics или другой трекинг без изменения кода.

**Как работает:** форматирует event и properties в строку и пишет через Logger.

---

## Infrastructure Layer

Отвечает за внешние взаимодействия: сеть, файлы, уведомления, геолокацию.

### ReminderRepository

**Расположение:** [SmartRemindera/Infrastructure/Persistence/ReminderRepository.swift](../SmartRemindera/SmartRemindera/Infrastructure/Persistence/ReminderRepository.swift)

**Назначение:** персистентное хранилище напоминаний и истории.

#### Архитектура хранения

**Что делает:** использует JSON-файл с версионированием и бэкапами.

**Почему так:** 
- Core Data избыточен для простой модели
- UserDefaults имеет лимиты размера
- JSON гибок и читаем

**Как работает:**
- Структура `Payload { version, reminders, histories }`
- Файл сохраняется в App Group (для доступа из Widget)
- Backup создаётся при каждом сохранении
- Миграция из legacy UserDefaults на первом запуске

#### Основные методы

##### `saveReminder(_:)` / `fetchReminder(id:)` / `deleteReminder(id:)`

Стандартные CRUD операции.

##### `fetchReminders(by status:)`

**Что делает:** фильтрует напоминания по статусу (scheduled, active, completed).

**Почему так:** UI нужны разные списки для разных экранов.

##### `fetchActiveReminder()`

**Что делает:** возвращает текущее активное напоминание (для Dynamic Island).

**Связь с другими компонентами:** вызывается только через coordinator. ViewModel'ы не имеют прямого доступа к repository.

---

### APIClient

**Расположение:** [SmartRemindera/Infrastructure/Network/APIClient.swift](../SmartRemindera/SmartRemindera/Infrastructure/Network/APIClient.swift)

**Назначение:** HTTP-клиент для синхронизации с сервером (заготовка).

#### `fetchReminders(endpoint:)` / `uploadReminder(_:endpoint:)`

**Что делает:** GET/POST запросы для синхронизации.

**Почему так:** отдельный слой для сетевых запросов упрощает замену на Alamofire или другой HTTP-клиент.

**Как работает:**
- URLSession с async/await
- JSON кодирование/декодирование с ISO8601 датами
- Обработка ошибок через кастомный enum `APIError`

**Текущий статус:** stub, не используется в production. Готов для будущего расширения.

---

### NotificationServiceImpl

**Расположение:** [SmartRemindera/Infrastructure/Services/NotificationServiceImpl.swift](../SmartRemindera/SmartRemindera/Infrastructure/Services/NotificationServiceImpl.swift)

**Назначение:** управление push-уведомлениями через UNUserNotificationCenter.

#### `requestPermissions()`

**Что делает:** запрашивает разрешения на уведомления.

**Как работает:**
- Запрашивает `.alert`, `.sound`, `.badge`, `.criticalAlert`
- Возвращает `Bool` — разрешил ли пользователь
- Бросает `NotificationError.permissionDenied` при отказе

#### `scheduleNotification(for:)`

**Что делает:** создаёт и планирует уведомление.

**Почему так:** уведомления должны отражать эскалацию и триггеры напоминания.

**Как работает:**
1. Создаёт `UNMutableNotificationContent` с title и body
2. Применяет эскалацию:
   - Уровень 0: `.default` звук
   - Уровень 4-5: `.defaultCritical` + `.timeSensitive`
   - Уровень 6+: `.defaultCritical` + `.critical` (прорывается через DND)
3. Создаёт trigger:
   - Для времени: `UNCalendarNotificationTrigger`
   - Для геолокации: `UNLocationNotificationTrigger` (в другом методе)
4. Добавляет `categoryIdentifier` для actions (Snooze, Complete)

#### `cancelNotification(for:)` / `updateNotification(for:)`

**Что делает:** отменяет или обновляет уведомление.

**Как работает:**
- Удаляет pending и delivered уведомления
- Для обновления: cancel + schedule

#### `setupNotificationCategories()`

**Что делает:** регистрирует actions для интерактивных уведомлений.

**Как работает:**
- Создаёт `UNNotificationAction` для "Complete" и "Snooze"
- Регистрирует `UNNotificationCategory`

**Связь с другими компонентами:** реализует протокол `NotificationService` из Domain слоя. Может быть заменён на mock для тестов.

---

### LocationServiceImpl

**Расположение:** [SmartRemindera/Infrastructure/Services/LocationServiceImpl.swift](../SmartRemindera/SmartRemindera/Infrastructure/Services/LocationServiceImpl.swift)

**Назначение:** управление геолокацией и геозонами через CoreLocation.

#### `requestPermissions()`

**Что делает:** запрашивает `.authorizedAlways` для работы геозон в фоне.

**Почему так:** геозоны работают только с `authorizedAlways`, не `whenInUse`.

**Как работает:**
- Проверяет текущий статус
- Запрашивает разрешения через `CLLocationManager`
- Ждёт callback через `CheckedContinuation`

#### `getCurrentLocation()`

**Что делает:** получает текущие координаты пользователя.

**Как работает:**
- Вызывает `locationManager.requestLocation()`
- Ждёт результат через continuation
- Возвращает `(latitude, longitude)`

#### `startMonitoring(trigger:for:)`

**Что делает:** запускает мониторинг геозоны.

**Почему так:** каждое геолокационное напоминание требует свою `CLCircularRegion`.

**Как работает:**
1. Создаёт `CLCircularRegion` с координатами и радиусом
2. Настраивает `notifyOnEntry`/`notifyOnExit` в зависимости от `triggerType`
3. Запускает мониторинг через `locationManager.startMonitoring(for:)`
4. Сохраняет в `monitoredRegions` для последующей отмены

#### `stopMonitoring(for:)`

**Что делает:** останавливает мониторинг геозоны для конкретного напоминания.

#### `onGeofenceTriggered` callback

**Что делает:** вызывается при входе/выходе из геозоны.

**Связь с другими компонентами:** coordinator подписывается на этот callback и активирует напоминание.

---

### LiveActivityServiceImpl

**Расположение:** [SmartRemindera/Infrastructure/Services/LiveActivityServiceImpl.swift](../SmartRemindera/SmartRemindera/Infrastructure/Services/LiveActivityServiceImpl.swift)

**Назначение:** управление Live Activities (Dynamic Island) для iOS 16.2+.

#### `startActivity(for:)` / `updateActivity(for:)` / `endActivity(for:)`

**Что делает:** создаёт, обновляет или завершает Live Activity.

**Почему так:** Live Activities требуют ActivityKit и работают только на iOS 16.2+.

**Как работает:**
1. Создаёт `ActivityAttributes` с данными напоминания
2. Запускает activity через `Activity<T>.request()`
3. Обновляет через `activity.update()`
4. Завершает через `activity.end()`

**Связь с другими компонентами:** вызывается координатором при активации/деактивации напоминания.

---

## Domain Layer (SmartRemindersCore)

Содержит бизнес-логику, независимую от UI и инфраструктуры.

### Entities

#### Reminder

**Расположение:** [SmartRemindersCore/Domain/Entities/Reminder.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/Entities/Reminder.swift)

**Назначение:** центральная модель данных напоминания.

**Поля:**
- `id: UUID` — уникальный идентификатор
- `title: String` — заголовок
- `notes: String?` — описание
- `scheduledDate: Date?` — временной триггер
- `locationTrigger: LocationTrigger?` — геолокационный триггер
- `priority: Priority` — приоритет (low, medium, high, critical)
- `status: Status` — текущий статус (created, scheduled, active, completed, snoozed, ignored)
- `escalationLevel: Int` — уровень эскалации (влияет на звук и критичность уведомления)
- `createdAt/updatedAt: Date` — метаданные

**Вложенные типы:**
- `Priority` — enum приоритетов
- `Status` — enum статусов
- `LocationTrigger` — структура с координатами, радиусом и типом триггера (enter/exit/both)

**Почему struct:** value semantics, Codable, Equatable из коробки.

#### ReminderHistory

**Назначение:** история взаимодействий с напоминанием.

**Поля:**
- `reminderId: UUID`
- `snoozeCount/ignoreCount/completionCount: Int`
- `completionDates: [Date]` — даты завершений для анализа паттернов
- `averageCompletionHour: Int?` — средний час завершения
- `completionRate: Double` — процент завершённых из запланированных
- `snoozeFrequency: Double` — среднее количество snooze на напоминание

**Почему так:** движок правил анализирует историю для адаптивного поведения.

#### ReminderDecision

**Назначение:** решение, принятое движком правил.

**Варианты:**
- `.noAction(because:)` — ничего не делать
- `.reschedule(to:because:escalationLevel:)` — перепланировать
- `.escalate(to:because:)` — повысить эскалацию
- `.suggest(_:confidence:)` — предложить пользователю изменение

**Связь с другими компонентами:** возвращается из `ReminderRulesEngine` и обрабатывается в UseCases.

---

### UseCases

#### CreateReminderUseCase

**Расположение:** [SmartRemindersCore/Domain/UseCases/CreateReminderUseCase.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/UseCases/CreateReminderUseCase.swift)

**Назначение:** инкапсулирует логику создания напоминания.

**Что делает:**
1. Валидирует входные данные (title не пустой, дата в будущем, координаты валидны)
2. Создаёт объект `Reminder`
3. Планирует уведомление через `notificationService`
4. Запускает геозону через `locationService`
5. Возвращает готовое напоминание

**Почему так:** вся логика валидации и создания в одном месте, легко тестируется.

#### SnoozeReminderUseCase

**Назначение:** обрабатывает snooze с применением правил.

**Что делает:**
1. Вызывает `rulesEngine.evaluate()` для анализа паттернов
2. Применяет решение (увеличивает snooze, повышает эскалацию)
3. Обновляет `ReminderHistory` (увеличивает snooze count)
4. Возвращает обновлённое напоминание, историю и решение

**Почему так:** snooze — это не тривиальная операция, требует анализа поведения.

#### CompleteReminderUseCase

**Назначение:** завершает напоминание.

**Что делает:**
1. Отменяет уведомление
2. Останавливает геозону
3. Завершает Live Activity
4. Обновляет историю (увеличивает completion count, записывает дату)
5. Вычисляет `averageCompletionHour` для оптимизации времени

**Почему так:** все cleanup-действия инкапсулированы в одном месте.

#### EvaluateReminderUseCase

**Назначение:** оценивает напоминание без изменения (для фоновых задач).

**Что делает:** вызывает rules engine и возвращает suggestion без применения изменений.

**Почему так:** используется для аналитики и предложений, а не для автоматических изменений.

---

### ReminderRulesEngine

**Расположение:** [SmartRemindersCore/Domain/Rules/ReminderRulesEngine.swift](../SmartRemindersCore/Sources/SmartRemindersCore/Domain/Rules/ReminderRulesEngine.swift)

**Назначение:** центральный движок правил. Берёт напоминание и историю, прогоняет через набор правил и выбирает самое уверенное решение.

#### `init(rules: [ReminderRule] = [])`

**Что делает:** инициализирует движок. Если список правил не передан, подключает набор по умолчанию.

**Почему так:** чтобы работал «из коробки», но при этом позволял подменять правила (например, в тестах или при расширении продукта).

**Как работает:**
- Если `rules` пуст, вызывает `defaultRules()` и сохраняет результат.
- Иначе сохраняет переданный список.

#### `evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision`

**Что делает:** вычисляет решение для напоминания на основе всех правил.

**Почему так:** каждое правило отвечает за один аспект логики, а выбор итогового решения должен быть централизован.

**Как работает:**
- Вызывает `evaluate` у каждого правила.
- Отбрасывает `nil` (неприменимые правила).
- Возвращает решение с максимальной `confidence`.
- Если решений нет — возвращает `.noAction` с причиной.

#### `defaultRules() -> [ReminderRule]`

**Что делает:** возвращает набор базовых правил.

**Почему так:** гарантирует минимальный полезный функционал без конфигурации.

**Как работает:** создаёт и возвращает массив правил:
- `SnoozePatternRule`
- `EscalationRule`
- `TimeOfDayOptimizationRule`
- `LocationSuggestionRule`

---

### Правила движка

#### SnoozePatternRule

**Назначение:** анализирует паттерны «откладывания» и корректирует длительность snooze.

**Что делает:** решает, нужно ли пересчитать время напоминания после snooze.

**Почему так:** частые snooze обычно означают, что интервал слишком короткий.

**Как работает:**
- Применяется только если `reminder.status == .snoozed` и `history.snoozeCount > 0`.
- Если `snoozeCount >= 3`:
  - Берёт базу 15 минут.
  - Умножает на `min(snoozeCount, 8)`.
  - Возвращает `.reschedule` с новой датой и сообщением.
  - Эскалация: `min(snoozeCount / 2, 3)`.
- Иначе возвращает стандартный snooze на 10 минут.

#### EscalationRule

**Назначение:** повышает приоритет (эскалацию), если напоминание игнорируется или бесконечно откладывается.

**Что делает:** решает, нужно ли повысить уровень эскалации.

**Почему так:** игнорирование может означать важность задачи или недостаточно заметный уровень приоритета.

**Как работает:**
- Если `ignoreCount >= 2`, возвращает `.escalate` с новым уровнем `reminder.escalationLevel + 1`.
- Иначе, если `snoozeCount >= 5` и `completionCount == 0`, тоже возвращает `.escalate`.
- В остальных случаях — `nil`.

#### TimeOfDayOptimizationRule

**Назначение:** предлагает перенос времени напоминания на более удобное, если видно устойчивый паттерн завершения.

**Что делает:** предлагает более подходящее время на основе средней «часовой» статистики выполнения.

**Почему так:** пользователю удобнее завершать задачи в привычный час.

**Как работает:**
- Требует `history.averageCompletionHour` и минимум 3 завершения (`completionCount >= 3`).
- Требует наличие `reminder.scheduledDate`.
- Сравнивает час напоминания с `averageCompletionHour`.
- Если разница >= 2 часов, формирует предложенную дату и возвращает `.suggest` с `confidence = 0.75`.
- Иначе — `nil`.

#### LocationSuggestionRule

**Назначение:** предлагает добавить триггер по локации, если напоминания часто откладываются.

**Что делает:** формирует рекомендацию добавить локацию (Дом/Офис).

**Почему так:** контекст по месту может повысить вероятность выполнения.

**Как работает:**
- Применяется только если у напоминания нет `locationTrigger`.
- Не предлагает ничего при высокой успешности (`completionRate >= 0.7`).
- Если `snoozeFrequency > 2.0`, возвращает `.suggest` с `confidence = 0.6`.
- Иначе — `nil`.

---

## Presentation Layer

Отвечает за UI и взаимодействие с пользователем.

### ViewModels

#### ReminderListViewModel

**Расположение:** [SmartRemindera/Presentation/ViewModels/ReminderListViewModel.swift](../SmartRemindera/SmartRemindera/Presentation/ViewModels/ReminderListViewModel.swift)

**Назначение:** управляет списком напоминаний.

**Что делает:**
- Подписывается на `coordinator.$reminders`
- Фильтрует по статусу через `displayedReminders`
- Предоставляет методы `deleteReminder()` и `activateReminder()`

**Почему так:** ViewModel не содержит бизнес-логики, только UI-логику (фильтрация, форматирование).

#### CreateReminderViewModel

**Расположение:** [SmartRemindera/Presentation/ViewModels/CreateReminderViewModel.swift](../SmartRemindera/SmartRemindera/Presentation/ViewModels/CreateReminderViewModel.swift)

**Назначение:** управляет формой создания напоминания.

**Что делает:**
- Хранит @Published поля формы (title, notes, scheduledDate, location)
- Валидирует через `canSave`
- Запрашивает текущую локацию через `getCurrentLocation()`
- Вызывает `coordinator.createReminder()` при `save()`

**Почему так:** вся UI-логика формы изолирована от бизнес-логики создания.

#### ActiveReminderViewModel

**Расположение:** [SmartRemindera/Presentation/ViewModels/ActiveReminderViewModel.swift](../SmartRemindera/SmartRemindera/Presentation/ViewModels/ActiveReminderViewModel.swift)

**Назначение:** управляет экраном активного напоминания.

**Что делает:**
- Подписывается на `coordinator.$activeReminder`
- Запускает таймер для обновления `timeRemaining`
- Предоставляет методы `snooze()` и `complete()`
- Показывает следующее запланированное напоминание

**Почему так:** UI нужен live-обновление оставшегося времени.

---

## Widgets и Extensions

### SmartReminderaWidgets

**Расположение:** `SmartReminderaWidgets/`

**Назначение:** Home Screen виджеты и Live Activities.

**Компоненты:**
- `SmartReminderaWidgetsBundle.swift` — точка входа для всех виджетов
- `ReminderLiveActivity.swift` — Live Activity для Dynamic Island
- `ReminderAppIntents.swift` — App Intents для быстрых действий
- `ReminderShortcuts.swift` — Siri Shortcuts

**Как работает:**
- Виджеты читают данные из App Group (shared container)
- Live Activities обновляются координатором при изменении напоминания
- App Intents позволяют создавать/завершать напоминания через Siri и Shortcuts

**Связь с основным приложением:** используют `SmartRemindersCore` для моделей данных, но не имеют доступа к Infrastructure слою (нет нотификаций и геолокации).

---

## Как всё работает вместе

### Сценарий 1: Создание напоминания

1. Пользователь открывает `CreateReminderView`
2. `CreateReminderViewModel` отображает форму
3. Пользователь заполняет title, выбирает время
4. ViewModel вызывает `coordinator.createReminder()`
5. Coordinator вызывает `createUseCase.execute()`
6. UseCase:
   - Валидирует данные
   - Создаёт объект `Reminder`
   - Вызывает `notificationService.scheduleNotification()`
7. Coordinator сохраняет через `repository.saveReminder()`
8. Repository пишет в JSON
9. Coordinator перезагружает список
10. UI автоматически обновляется через `@Published`

### Сценарий 2: Snooze с эскалацией

1. Пользователь нажимает "Snooze" в уведомлении или на `ActiveReminderView`
2. `ActiveReminderViewModel` вызывает `coordinator.snoozeReminder()`
3. Coordinator загружает `reminder` и `history`
4. Вызывает `snoozeUseCase.execute(reminder, history)`
5. UseCase вызывает `rulesEngine.evaluate(reminder, history)`
6. Rules Engine:
   - `SnoozePatternRule` видит `snoozeCount = 4`
   - Возвращает `.reschedule(to: +60min, escalationLevel: 2)`
7. UseCase применяет решение:
   - Обновляет `reminder.scheduledDate`
   - Повышает `reminder.escalationLevel = 2`
   - Увеличивает `history.snoozeCount`
8. Coordinator сохраняет изменения
9. Вызывает `notificationService.updateNotification()` с новым временем и критичным звуком
10. UI показывает сообщение: "You've snoozed this 4 times. Extending snooze to 60 minutes"

### Сценарий 3: Геолокационный триггер

1. Пользователь создаёт напоминание с location trigger "Дом"
2. `createUseCase` вызывает `locationService.startMonitoring(trigger, reminderId)`
3. `LocationServiceImpl` создаёт `CLCircularRegion` и запускает мониторинг
4. Пользователь входит в геозону
5. iOS вызывает `CLLocationManagerDelegate.didEnterRegion()`
6. `LocationServiceImpl` вызывает callback `onGeofenceTriggered(reminderId)`
7. Coordinator получает event и вызывает `activateReminder(id)`
8. Напоминание переходит в статус `.active`
9. Запускается Live Activity в Dynamic Island
10. Показывается уведомление

### Сценарий 4: Фоновое обновление

1. Система iOS запускает `BGAppRefreshTask` через 30 минут
2. `BackgroundTaskManager.handleRefresh()` вызывается
3. Получает список всех `.scheduled` напоминаний
4. Для каждого вызывает `notificationService.updateNotification()`
5. Если правила движка предлагают изменения, применяет их
6. Завершает task, сообщая успех системе
7. Планирует следующий запуск

---

## Преимущества архитектуры

✅ **Тестируемость:** Domain слой можно тестировать без UI и инфраструктуры  
✅ **Независимость:** бизнес-логика не зависит от SwiftUI, UIKit, CoreData  
✅ **Переиспользуемость:** `SmartRemindersCore` используется в app, widgets, extensions  
✅ **Расширяемость:** добавление новых правил не требует изменения существующего кода  
✅ **Понятность:** чёткое разделение ответственности между слоями

---

## Что можно улучшить

🔹 **Синхронизация:** добавить реальный бэкенд для облачной синхронизации через `APIClient`  
🔹 **Аналитика:** интегрировать Firebase Analytics вместо os.log  
🔹 **Персонализация:** использовать ML для более точных предсказаний времени выполнения  
🔹 **Тесты:** добавить UI-тесты и интеграционные тесты  
🔹 **Accessibility:** улучшить поддержку VoiceOver и Dynamic Type

---

Этот документ содержит полное пофункциональное описание всех компонентов проекта SmartReminders. Для детального изучения конкретных файлов используйте ссылки на исходный код.
