#if WIDGET_EXTENSION
import SwiftUI
import ActivityKit
import WidgetKit
import AppIntents
import SmartRemindersCore

/// Live Activity UI for reminders
@available(iOS 16.1, *)
struct ReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderActivityAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.title, systemImage: "bell.fill")
                        .font(.caption)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timeRemaining(from: context.state.scheduledDate))
                        .font(.caption)
                        .monospacedDigit()
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 8) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(2)

                        if let notes = context.state.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        
                        if let locationName = context.state.locationName, !locationName.isEmpty {
                            Label(locationName, systemImage: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 8) {
                            activityBadge(text: context.state.status, tint: .blue)
                            activityBadge(text: priorityLabel(context.state.priorityRaw), tint: priorityColor(context.state.priorityRaw))
                        }
                        
                        HStack(spacing: 12) {
                            Button(intent: CompleteReminderIntent(reminderId: context.attributes.reminderId)) {
                                Label("Done", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                            }
                            .tint(.green)
                            
                            Button(intent: SnoozeReminderIntent(reminderId: context.attributes.reminderId)) {
                                Label("Snooze", systemImage: "clock.fill")
                                    .font(.caption)
                            }
                            .tint(.orange)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    escalationIndicator(level: context.state.escalationLevel)
                }
            } compactLeading: {
                Image(systemName: "bell.fill")
            } compactTrailing: {
                Text(timeRemaining(from: context.state.scheduledDate))
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "bell.fill")
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func timeRemaining(from date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        
        if interval < 0 {
            return "Now"
        }
        
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    @ViewBuilder
    private func escalationIndicator(level: Int) -> some View {
        if level > 0 {
            HStack(spacing: 4) {
                ForEach(0..<min(level, 3), id: \.self) { _ in
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
    }

}

/// Lock screen Live Activity view
@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<ReminderActivityAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.blue)
                
                Text(context.attributes.title)
                    .font(.headline)
                
                Spacer()
                
                Text(timeRemaining(from: context.state.scheduledDate))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if let notes = context.state.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            if let locationName = context.state.locationName, !locationName.isEmpty {
                Label(locationName, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 8) {
                activityBadge(text: context.state.status, tint: .blue)
                activityBadge(text: priorityLabel(context.state.priorityRaw), tint: priorityColor(context.state.priorityRaw))
            }
            
            HStack(spacing: 12) {
                Button(intent: CompleteReminderIntent(reminderId: context.attributes.reminderId)) {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button(intent: SnoozeReminderIntent(reminderId: context.attributes.reminderId)) {
                    Label("Snooze", systemImage: "clock.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            
            if context.state.escalationLevel > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<min(context.state.escalationLevel, 3), id: \.self) { _ in
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    Text("Priority escalated")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
    
    private func timeRemaining(from date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        
        if interval < 0 {
            return "Now"
        }
        
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Shared helpers

private func activityBadge(text: String, tint: Color) -> some View {
    Text(text)
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.15))
        .foregroundStyle(tint)
        .clipShape(Capsule())
}

private func priorityLabel(_ raw: String) -> String {
    raw.capitalized
}

private func priorityColor(_ raw: String) -> Color {
    switch raw.lowercased() {
    case "low": return .gray
    case "medium": return .blue
    case "high": return .orange
    case "critical": return .red
    default: return .secondary
    }
}

// MARK: - Upcoming reminders Home/Lock widgets

@available(iOS 17.0, *)
struct UpcomingReminderEntry: TimelineEntry {
    let date: Date
    let reminders: [Reminder]
}

@available(iOS 17.0, *)
struct UpcomingConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Напоминания"
    static var description = IntentDescription("Показывает ближайшие напоминания")
}

@available(iOS 17.0, *)
struct UpcomingReminderProvider: AppIntentTimelineProvider {
    func placeholder(in context: TimelineProviderContext) -> UpcomingReminderEntry {
        UpcomingReminderEntry(date: Date(), reminders: sampleReminders())
    }
    
    func snapshot(for configuration: UpcomingConfigurationIntent, in context: TimelineProviderContext) async -> UpcomingReminderEntry {
        UpcomingReminderEntry(date: Date(), reminders: sampleReminders())
    }
    
    func timeline(for configuration: UpcomingConfigurationIntent, in context: TimelineProviderContext) async -> Timeline<UpcomingReminderEntry> {
        let entry = await loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(next))
    }
    
    private func loadEntry() async -> UpcomingReminderEntry {
        if let reminders = loadSharedReminders(), !reminders.isEmpty {
            return UpcomingReminderEntry(date: Date(), reminders: reminders)
        }
        return UpcomingReminderEntry(date: Date(), reminders: sampleReminders())
    }
    
    private func sampleReminders() -> [Reminder] {
        [Reminder(title: "Sample reminder", scheduledDate: Date().addingTimeInterval(3600))]
    }
    
    /// Read reminders from shared app group storage; falls back to sample if unavailable.
    private func loadSharedReminders() -> [Reminder]? {
        let appGroupId = (Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let appGroupId, !appGroupId.isEmpty,
              let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        let fileURL = containerURL.appendingPathComponent("reminders.json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        struct Payload: Decodable { let reminders: [Reminder]? }
        if let payload = try? JSONDecoder().decode(Payload.self, from: data), let reminders = payload.reminders {
            return reminders
                .filter { $0.status == .scheduled && $0.scheduledDate != nil }
                .sorted { ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture) }
                .prefix(3)
                .map { $0 }
        }
        return nil
    }
}

@available(iOS 17.0, *)
struct UpcomingReminderWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "UpcomingReminderWidget", intent: UpcomingConfigurationIntent.self, provider: UpcomingReminderProvider()) { entry in
            UpcomingReminderView(entry: entry)
        }
        .configurationDisplayName("Ближайшие напоминания")
        .description("Показывает до трёх следующих напоминаний")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@available(iOS 17.0, *)
struct UpcomingReminderView: View {
    let entry: UpcomingReminderEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.reminders.isEmpty {
                Label("Нет запланированных", systemImage: "bell.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.reminders.prefix(3), id: \.id) { reminder in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.title)
                                .font(.caption)
                                .lineLimit(1)
                            if let date = reminder.scheduledDate {
                                Text(date, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(reminder.priority.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(priorityColor(reminder.priority).opacity(0.15))
                            .foregroundStyle(priorityColor(reminder.priority))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) { Color.clear }
    }
    
    private func priorityColor(_ priority: Reminder.Priority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}
// Entry point is defined in SmartReminderaWidgetsBundle.swift
#endif
