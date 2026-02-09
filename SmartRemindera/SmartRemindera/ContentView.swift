//
//  ContentView.swift
//  SmartRemindera
//
//  Created by Лейла Жунисбекова on 09.02.2026.
//

import SwiftUI

struct ContentView: View {
    let container: DependencyContainer
    @StateObject private var permissionsVM = PermissionsViewModel()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("dailyGoal") private var dailyGoal = 3
    @State private var showOnboarding = false
    
    var body: some View {
        VStack(spacing: 0) {
            if permissionsVM.needsAttention {
                PermissionsBannerView(viewModel: permissionsVM)
            }
            TabView {
                ReminderListView(
                    coordinator: container.coordinator,
                    locationService: container.locationService
                )
                .tabItem {
                    Label("Reminders", systemImage: "list.bullet")
                }
                
                ActiveReminderView(coordinator: container.coordinator, locationService: container.locationService)
                    .tabItem {
                        Label("Active", systemImage: "bell.fill")
                    }
                
                StatsView(coordinator: container.coordinator)
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }
            }
        }
        .task {
            await permissionsVM.refresh()
            showOnboarding = !hasSeenOnboarding
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(dailyGoal: $dailyGoal) {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
    }
}

