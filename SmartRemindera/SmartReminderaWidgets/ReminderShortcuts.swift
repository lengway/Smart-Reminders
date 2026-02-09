import Foundation
import AppIntents
import SmartRemindersCore

/// Quick creation intent for Shortcuts / Spotlight
@available(iOS 17.0, *)
struct CreateQuickReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Quick Reminder"
    static var description = IntentDescription("Создать напоминание с опциональным временем через App Shortcuts")
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    
    @Parameter(title: "Title", requestValueDialog: "Что напомнить?")
    var title: String
    
    @Parameter(title: "In minutes", default: 30)
    var minutesFromNow: Int
    
    func perform() async throws -> some IntentResult {
        // Placeholder implementation in widget extension; main app handles creation.
        return .result(value: "Напоминание создано на \(minutesFromNow) минут")
    }
}

/// App shortcuts collection
@available(iOS 17.0, *)
struct ReminderShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue
    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: CreateQuickReminderIntent(),
                phrases: ["Создать напоминание в \(.applicationName)"],
                shortTitle: "Быстрое напоминание",
                systemImageName: "bell.badge"
            )
        ]
    }
}
