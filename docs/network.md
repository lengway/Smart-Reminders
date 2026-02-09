# Документация сети (стаб и примеры)

Этот документ содержит минимальные инструкции и примеры запросов для интеграции REST API с приложением.

1) Пример структуры эндпоинта

- GET /reminders — получить массив напоминаний (JSON -> [Reminder])
- POST /reminders — создать/синхронизировать напоминание (JSON body -> Reminder)

Пример JSON элемента (соответствует `Reminder` из `SmartRemindersCore`):

```json
{
  "id": "UUID-string",
  "title": "Buy milk",
  "notes": "2%",
  "scheduledDate": "2026-02-09T12:00:00Z",
  "locationTrigger": null,
  "priority": "medium",
  "status": "scheduled",
  "escalationLevel": 0,
  "createdAt": "2026-02-08T08:00:00Z",
  "updatedAt": "2026-02-08T08:00:00Z"
}
```

2) Пример cURL

```bash
curl -sS https://api.example.com/reminders

curl -X POST https://api.example.com/reminders \
  -H "Content-Type: application/json" \
  -d '{ "title":"Sample" }'
```

3) Postman / коллекция

- Создайте коллекцию с GET /reminders и POST /reminders. Используйте `application/json`.

4) Как интегрировать в проект

- Файл-клиент: `SmartRemindera/SmartRemindera/Infrastructure/Network/APIClient.swift` — предоставляет `fetchReminders()` и `uploadReminder(_:)`.
- В `ReminderCoordinator` можно добавить опциональную зависимость `apiClient: APIClient` и вызвать `fetchReminders()` при старте для синхронизации.

Пример (псевдо-код):

```swift
// В Coordinator.init
let api = APIClient(baseURL: URL(string: "https://api.example.com/")!)
Task {
  do {
    let remote = try await api.fetchReminders()
    // мердж/сохранить в ReminderRepository
  } catch {
    // обработать ошибку загрузки
  }
}
```
