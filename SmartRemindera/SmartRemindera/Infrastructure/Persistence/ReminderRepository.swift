import Foundation
import SmartRemindersCore

/// Repository for persisting reminders and history with simple versioned file storage
public actor ReminderRepository {
    private struct Payload: Codable {
        var version: Int
        var reminders: [Reminder]
        var histories: [ReminderHistory]
    }
    
    private let fileManager = FileManager.default
    private let filename = "reminders.json"
    // Optional App Group identifier; if nil or unavailable we fall back to documents to avoid entitlement errors.
    private let appGroupId: String? = {
        // If you add App Group, set "AppGroupIdentifier" in Info.plist or replace this with your group id.
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
    private let backupFilename = "reminders.backup.json"
    private let userDefaults = UserDefaults.standard
    private let legacyRemindersKey = "reminders"
    private let legacyHistoriesKey = "histories"
    private let currentVersion = 1
    
    public init() {}
    
    // MARK: - Reminders
    
    public func saveReminder(_ reminder: Reminder) throws {
        var payload = try loadPayload()
        
        if let index = payload.reminders.firstIndex(where: { $0.id == reminder.id }) {
            payload.reminders[index] = reminder
        } else {
            payload.reminders.append(reminder)
        }
        
        try persist(payload)
    }
    
    public func fetchReminder(id: UUID) throws -> Reminder? {
        let payload = try loadPayload()
        return payload.reminders.first { $0.id == id }
    }
    
    public func fetchAllReminders() throws -> [Reminder] {
        let payload = try loadPayload()
        return payload.reminders
    }
    
    public func deleteReminder(id: UUID) throws {
        var payload = try loadPayload()
        payload.reminders.removeAll { $0.id == id }
        try persist(payload)
    }
    
    // MARK: - History
    
    public func saveHistory(_ history: ReminderHistory) throws {
        var payload = try loadPayload()
        
        if let index = payload.histories.firstIndex(where: { $0.reminderId == history.reminderId }) {
            payload.histories[index] = history
        } else {
            payload.histories.append(history)
        }
        
        try persist(payload)
    }
    
    public func fetchHistory(for reminderId: UUID) throws -> ReminderHistory {
        let payload = try loadPayload()
        
        if let history = payload.histories.first(where: { $0.reminderId == reminderId }) {
            return history
        }
        
        return ReminderHistory(reminderId: reminderId)
    }
    
    public func fetchAllHistories() throws -> [ReminderHistory] {
        let payload = try loadPayload()
        return payload.histories
    }
    
    // MARK: - Queries
    
    public func fetchReminders(by status: Reminder.Status) throws -> [Reminder] {
        let payload = try loadPayload()
        return payload.reminders.filter { $0.status == status }
    }
    
    public func fetchActiveReminder() throws -> Reminder? {
        let payload = try loadPayload()
        return payload.reminders.first { $0.status == .active }
    }
    
    public func fetchUpcomingReminders(limit: Int = 10) throws -> [Reminder] {
        let payload = try loadPayload()
        return payload.reminders
            .filter { $0.status == .scheduled && $0.scheduledDate != nil }
            .sorted { ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture) }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Storage
    
    private func loadPayload() throws -> Payload {
        // Attempt primary file load
        if let data = try? Data(contentsOf: storageURL()),
           let decoded = try? JSONDecoder().decode(Payload.self, from: data) {
            return decoded
        }
        
        // Attempt migration from legacy UserDefaults
        if let migrated = try? migrateFromLegacy() {
            return migrated
        }
        
        // Fallback empty payload
        return Payload(version: currentVersion, reminders: [], histories: [])
    }
    
    private func persist(_ payload: Payload) throws {
        var mutablePayload = payload
        mutablePayload.version = currentVersion
        let data = try JSONEncoder().encode(mutablePayload)
        let url = try storageURL()
        try data.write(to: url, options: [.atomic])
        try? data.write(to: url.deletingLastPathComponent().appendingPathComponent(backupFilename), options: [.atomic])
    }
    
    private func storageURL() throws -> URL {
        // Prefer shared app group container so widgets/Intents can read the same store
        if let appGroupId, !appGroupId.isEmpty,
           let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            return container.appendingPathComponent(filename)
        }
        
        let docs = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return docs.appendingPathComponent(filename)
    }
    
    private func migrateFromLegacy() throws -> Payload {
        let remindersData = userDefaults.data(forKey: legacyRemindersKey)
        let historiesData = userDefaults.data(forKey: legacyHistoriesKey)
        
        let reminders = (try? remindersData.flatMap { try JSONDecoder().decode([Reminder].self, from: $0) }) ?? []
        let histories = (try? historiesData.flatMap { try JSONDecoder().decode([ReminderHistory].self, from: $0) }) ?? []
        
        let payload = Payload(version: currentVersion, reminders: reminders, histories: histories)
        try persist(payload)
        
        // Clean legacy keys to avoid divergence
        userDefaults.removeObject(forKey: legacyRemindersKey)
        userDefaults.removeObject(forKey: legacyHistoriesKey)
        
        return payload
    }

    // MARK: - Health check
    
    public func validateStore() async -> Bool {
        do {
            _ = try loadPayload()
            return true
        } catch {
            // Attempt restore from backup
            if let backup = try? Data(contentsOf: try storageURL().deletingLastPathComponent().appendingPathComponent(backupFilename)),
               let decoded = try? JSONDecoder().decode(Payload.self, from: backup) {
                try? persist(decoded)
                return true
            }
            return false
        }
    }
}
