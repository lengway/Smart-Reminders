//
//  SmartReminderaApp.swift
//  SmartRemindera
//
//  Created by Лейла Жунисбекова on 09.02.2026.
//

import SwiftUI
import SmartRemindersCore
import BackgroundTasks

@main
struct SmartReminderaApp: App {
    @StateObject private var container = DependencyContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                .task {
                    await requestPermissions()
                    BackgroundTaskManager.shared.configure(
                        coordinator: container.coordinator,
                        notificationService: container.notificationService
                    )
                }
        }
    }
    
    private func requestPermissions() async {
        // Request notification permissions
        _ = try? await container.notificationService.requestPermissions()
        
        // Request location permissions
        _ = try? await container.locationService.requestPermissions()
        _ = await container.repository.validateStore()
    }
}
